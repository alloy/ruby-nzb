require 'nzb/parser'

class NZB
  class << self
    attr_accessor :result_directory
    
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
      queued.shift if queued.first and queued.first.done?
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
  
  def working_directory
    @working_directory ||= ::File.join(NZB.result_directory, ::File.basename(@path, '.nzb'))
  end
  
  # This is called by NZB.request_file
  def request_file
    @queue.shift
  end
  
  def done?
    @queue.empty?
  end
end