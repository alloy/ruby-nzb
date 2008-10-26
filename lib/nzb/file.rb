require 'nzb/segment'

class NZB
  class File
    attr_reader :segments, :queue, :processing
    
    def initialize
      @segments, @queue = [], []
    end
    
    def ==(other)
      @segments == other.segments
    end
    
    def add_segment(attrs)
      segment = Segment.new(attrs)
      @segments << segment
      @queue << segment
      segment
    end
    
    # This is called by NZB::File
    def request_job
      @processing = @queue.shift
    end
    
    def done?
      @queue.empty?
    end
  end
end