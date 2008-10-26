require 'nzb/parser'

class NZB
  class << self
    def queued
      @queue ||= []
    end
    
    def queue(path)
      (queued << new(path)).last
    end
    
    def clear_queue!
      @queue = []
    end
    
    # This is going to be called by the connection(s).
    def request_file
      if nzb = queued.first
        nzb.request_file
      end
    end
  end
  
  attr_reader :path, :files, :queue
  
  def initialize(path)
    @path = path
    @queue = (@files = Parser.new(@path).files).dup
  end
  
  # This is called by NZB.request_file
  def request_file
    @queue.shift
  end
end