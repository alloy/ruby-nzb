require 'nzb/parser'

class NZB
  attr_reader :path, :files
  
  def initialize(path)
    @path = path
    @files = Parser.new(@path).files
  end
  
  # This is going to be called by the connection.
  def request_job
    
  end
end