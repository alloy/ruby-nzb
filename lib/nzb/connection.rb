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
        (NZB.pool_size - pool.length).times do
          pool << connect(NZB.host, NZB.port)
        end
      end
      
      def connect(host, port)
        EventMachine.connect(host, port, self)
      end
      
      def connection_closed(connection)
        pool.delete(connection)
      end
      
      FILL_POOL_TIMER = (lambda do
        EventMachine::PeriodicTimer.new(2) do
          NZB::Connection.fill_pool!
        end
      end)
      
      def start_eventmachine_runloop!
        return if EventMachine.reactor_running?
        if NZB.blocking
          EventMachine.run do
            FILL_POOL_TIMER.call
            yield
          end
        else
          Thread.new { EventMachine.run { FILL_POOL_TIMER.call } }
          yield
        end
      end
    end
    
    END_OF_MESSAGE = /\r\n\.\r\n/
    
    def initialize(*args)
      super
      @ready = false
      @data = ''
      
      puts "Opening connection."
    end
    
    def ready?
      @ready
    end
    
    def receive_data(data)
      log "Received data: #{data}"
      
      if !ready?
        if data =~ /^200\s/
          log "Ready"
          @ready = true
          request_job
        end
      else
        @data << data
        if data =~ END_OF_MESSAGE
          log "Writing data"
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
        log "Send: #{request}"
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
      # @data.gsub!(/^222.+end=\d+\r\n/m, '')
      # @data.gsub!(/\r\n=yend.+\r\n\.\r\n$/, '')
    end
    
    def unbind
      puts "Closing connection."
      NZB::Connection.connection_closed(self)
    end
    
    def log(str)
      puts "Client: #{str}" if ENV['LOG_DATA'] == 'true'
    end
  end
end