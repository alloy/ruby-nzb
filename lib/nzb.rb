require 'nzb/parser'

class NZB
  attr_reader :path, :files, :queue, :processing
  
  def initialize(path)
    @path = path
    @files = Parser.new(@path).files
    @queue = @files.dup
    @processing = nil
  end
  
  # This is going to be called by the connection.
  def request_segment_job
    @processing ||= @queue.shift
    @processing.request_job
  end
end