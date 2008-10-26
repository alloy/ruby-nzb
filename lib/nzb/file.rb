require 'nzb/segment'

class NZB
  class File
    attr_reader :segments
    
    def initialize(message_ids = nil)
      @segments = []
    end
    
    def ==(other)
      @segments == other.segments
    end
    
    def add_segment(attrs)
      segment = Segment.new(attrs)
      @segments << segment
      segment
    end
  end
end