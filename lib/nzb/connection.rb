require 'rubygems'
require 'eventmachine'

class NZB
  class Connection < EventMachine::Connection
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
    
    END_OF_MESSAGE = /\r\n\.\r\n/
    
    def initialize(*args)
      super
      @ready = false
      @data = ''
      logger.debug "Connection: opening"
    end
    
    def ready?
      @ready
    end
    
    def current_file
      @file
    end
    
    def receive_data(data)
      if data =~ /^(\d{3}\s.+)\r\n/
        logger.debug $1
      end
      
      if !ready?
        if data =~ /^(200\s.+)\r\n/
          logger.debug "Ready: #{$1}"
          @ready = true
          request_job
        end
      else
        @data << data
        if data =~ END_OF_MESSAGE
          logger.debug "Connection: received all data for segment"
          unescape_data!
          @file.write_data(@data)
          
          @file = nil if @file.done?
          @data = ''
          
          request_job
        end
      end
    end
    
    def request_job
      if @file ||= NZB.request_file
        @segment = @file.request_job
        
        request = "BODY <#{@segment.message_id}>\r\n"
        logger.debug "Connection: send data \"#{request.strip}\""
        send_data request
      else
        close_connection
      end
    end
    
    # Start of data:
    # 222 0 <1224818241.27404.1@europe.news.astraweb.com> body\r\n
    # =ybegin part=1 total=39 line=128 size=15000000 name=name_of_the_file.zip\r\n
    # =ypart begin=1 end=386000\r\n
    # 
    # End of data:
    # yend size=386000 part=1 pcrc32=d94a027f\r\n.\r\n
    def unescape_data!
      @data.gsub!(/\r\n\.\./, "\r\n.")
    end
    
    def unbind
      @file.requeue! if @file
      logger.debug "Connection: closing"
      NZB::Connection.connection_closed(self)
    end
  end
end