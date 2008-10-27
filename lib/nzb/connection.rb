require 'rubygems'
require 'eventmachine'

class NZB
  class Connection < EventMachine::Connection
    class << self
      attr_reader :pool
      
      def start_pool!
        return if @pool
        start_eventmachine_runloop! do
          @pool = Array.new(NZB.pool_size) { connect(NZB.host, NZB.port) }
        end
      end
      
      def connect(host, port)
        EventMachine.connect(host, port, self)
      end
      
      def start_eventmachine_runloop!
        if NZB.blocking
          EventMachine.run { yield }
        else
          Thread.new { EventMachine.run {} }
          yield
        end
      end
    end
    
    END_OF_MESSAGE = /\r\n\.\r\n/
    
    def initialize(*args)
      super
      @ready = false
      @data = ''
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
    
    def unescape_data!
      @data.gsub!(/\r\n\.\./, "\r\n.")
    end
    
    def log(str)
      puts "Client: #{str}" if ENV['LOG_DATA'] == 'true'
    end
  end
end