module Kernel
  unless respond_to?(:logger)
    require 'logger'
    NZB.logger = Logger.new(STDERR)
    NZB.logger.level = Logger::ERROR
    NZB.logger.datetime_format = "%H:%M:%S"
    
    def logger
      NZB.logger
    end
  end
end