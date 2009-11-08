require 'rubygems'
require 'eventmachine'

class NZB
  class Connection < EventMachine::Connection
    class NeedsAuthentication < StandardError; end
    
    class << self
      def pool
        @pool ||= []
      end
      
      def start_pool!
        return if pool.length == NZB.pool_size
        start_eventmachine_runloop! { fill_pool! }
      end
      
      def fill_pool!
        max = (NZB.number_of_queued_files < NZB.pool_size) ? NZB.number_of_queued_files : NZB.pool_size
        needed = (max - pool.length)
        logger.debug "Need #{needed} connections"
        needed.times { pool << connect(NZB.host, NZB.port) }
      end
      
      def connect(host, port)
        EventMachine.connect(host, port, self)
      end
      
      def connection_closed(connection)
        pool.delete(connection)
      end
      
      def start_eventmachine_runloop!
        return if EventMachine.reactor_running?
        if NZB.blocking
          EventMachine.run do
            start_fill_pool_timer!
            yield
          end
        else
          Thread.new { EventMachine.run { start_fill_pool_timer! } }
          yield
        end
      end
      
      def start_fill_pool_timer!
        EventMachine::PeriodicTimer.new(2) do
          NZB::Connection.fill_pool!
        end
      end
    end
    
    attr_reader :received_data
    
    YENC_HEADER = /=ybegin.+name=(.+)\r\n/
    END_OF_MESSAGE = /\r\n\.\r\n/
    
    def initialize(*args)
      super
      @ready = @receiving_body_data = false
      setup_authentication
      @received_data = ''
      log "opening"
    end
    
    def current_file
      @file
    end
    
    def ready?
      @ready
    end
    
    def receiving_body_data?
      @receiving_body_data
    end
    
    def setup_authentication
      if NZB.user && NZB.password
        @authinfo_commands = ["AUTHINFO USER #{NZB.user}\r\n", "AUTHINFO PASS #{NZB.password}\r\n"]
        @need_to_authenticate = true
      end
    end
    
    def authenticate
      if @authinfo_commands && !@authinfo_commands.empty?
        send_data @authinfo_commands.shift
      else
        raise NeedsAuthentication
      end
    end
    
    def request_job
      if @file ||= NZB.request_file
        @segment = @file.request_job
        
        request = "BODY <#{@segment.message_id}>\r\n"
        log("send request: \"#{request.strip}\"")
        send_data request
      else
        log "no more jobs"
        close_connection
      end
    end
    
    # Some sample data:
    # 222 0 <1224818241.27404.1@europe.news.astraweb.com> body\r\n
    # =ybegin part=1 total=39 line=128 size=15000000 name=name_of_the_file.zip\r\n
    # =ypart begin=1 end=386000\r\n
    # 
    # End of data:
    # yend size=386000 part=1 pcrc32=d94a027f\r\n.\r\n
    def receive_data(data)
      return receive_body_data(data) if receiving_body_data?
      
      if data =~ /^(\d{3})\s(.+?)\r\n(.*)/m
        log("#{$1} #{$2}")
        case $1
        when '200'
          @ready = true
          connection_ready($2)
        when '222'
          @receiving_body_data = true
          receive_body_data($3)
        when '381'
          @need_to_authenticate = true
          connection_ready($2)
        when '281'
          @need_to_authenticate = false
          connection_ready($2)
        else
          log("UNIMPLEMENTED STATUS CODE: #{$1} - #{$2}", :error)
        end
      end
    end
    
    # User callback?
    def connection_ready(message)
      if @need_to_authenticate
        authenticate
      else
        request_job
      end
    end
    
    def receive_body_data(data)
      @received_data << data
      if data =~ YENC_HEADER
        @file.name = $1
      end
      if data =~ END_OF_MESSAGE
        @receiving_body_data = false
        segment_completed
      end
    end
    
    # User callback?
    def segment_completed
      log "received all data for segment"
      unescape_data!
      @file.write_data(@received_data)
      
      @file = nil if @file.done?
      @received_data = ''
      
      request_job
    end
    
    def unescape_data!
      @received_data.gsub!(/\r\n\.\./, "\r\n.")
    end
    
    def unbind
      @file.requeue! if @file
      log('closing')
      NZB::Connection.connection_closed(self)
    end
    
    def log(message, level = :debug)
      logger.send(level, "Connection [#{object_id}]: #{message}")
    end
  end
end