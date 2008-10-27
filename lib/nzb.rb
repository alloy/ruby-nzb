require 'nzb/parser'
require 'nzb/connection'
require 'fileutils'

class NZB
  class << self
    attr_accessor :host, :port, :pool_size, :output_directory, :blocking
    
    def setup(options)
      ({ :port => 119, :pool_size => 1, :blocking => true }.merge(options)).each { |key, value| send("#{key}=", value) }
    end
    
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
    @files = Parser.new(self).files
    @queue = @files.dup
    
    FileUtils.mkdir_p(output_directory) unless ::File.exist?(output_directory)
  end
  
  def output_directory
    @output_directory ||= ::File.join(NZB.output_directory, ::File.basename(@path, '.nzb'))
  end
  
  # This is called by NZB.request_file
  def request_file
    @queue.shift
  end
  
  def done?
    @queue.empty?
  end
end