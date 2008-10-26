require 'rubygems'
require 'eventmachine'

class NZB
  class Connection < EventMachine::Connection
    class << self
      def connect(host, port)
        EventMachine.connect(host, port, self)
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
          log "Write data: #{data}"
          @file.write_data(data)
          
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
    
    def log(str)
      puts "Client: #{str}" if ENV['LOG_DATA'] == 'true'
    end
  end
end