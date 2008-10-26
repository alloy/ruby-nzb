require 'rubygems'
require 'eventmachine'

class NZB
  class Connection < EventMachine::Connection
    class << self
      def connect(host, port)
        EventMachine.connect(host, port, self)
      end
    end
    
    def initialize(*args)
      super
      @ready = false
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
        end
      end
    end
    
    def log(str)
      puts "Client: #{str}"
    end
  end
end