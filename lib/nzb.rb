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
    
    def number_of_queued_files
      @queue.inject(0) { |sum, nzb| sum + nzb.files.length }
    end
    
    # This is going to be called by the connection(s).
    def request_file
      queued.shift if queued.first and queued.first.done?
      if nzb = queued.first
        nzb.request_file
      end
    end
  end
  
  attr_reader :path, :files, :queue, :on_update_callback
  
  def initialize(path)
    @path = path
    @files = Parser.new(self).files
    @queue = @files.dup
    
    unless ::File.exist?(output_directory)
      FileUtils.mkdir_p(output_directory)
      FileUtils.mkdir_p(work_directory)
    end
  end
  
  def output_directory
    @output_directory ||= ::File.join(NZB.output_directory, ::File.basename(@path, '.nzb'))
  end
  
  def work_directory
    @work_directory ||= ::File.join(output_directory, '.work')
  end
  
  # This is called by NZB.request_file
  def request_file
    @queue.shift
  end
  
  def requeue(file)
    puts "Requeing file."
    @queue.unshift file
  end
  
  def done?
    @queue.empty?
  end
  
  def bytes
    @bytes ||= @files.inject(0) { |sum, file| sum + file.bytes }
  end
  
  def downloaded_bytes
    @files.inject(0) { |sum, file| sum + file.downloaded_bytes }
  end
  
  def downloaded_percentage
    (downloaded_bytes * 100.0) / bytes
  end
  
  def on_update(&on_update_callback)
    @on_update_callback = on_update_callback
  end
  
  def run_update_callback!
    @on_update_callback.call(self) if @on_update_callback
  end
end