require 'nzb/segment'
require 'tempfile'

class NZB
  class File
    attr_reader :nzb, :segments, :queue, :processing, :tmp_file
    
    def initialize(nzb)
      @nzb = nzb
      @segments, @queue = [], []
    end
    
    def ==(other)
      @segments == other.segments
    end
    
    def done?
      @queue.empty?
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
    
    def write_data(data)
      @tmp_file ||= Tempfile.new(object_id)
      @tmp_file.write(data)
      
      if done?
        @tmp_file.close
        decode!
        ::File.unlink(@tmp_file.path)
      end
    end
    
    def decode!
      `uudeview -i -p '#{nzb.output_directory}' '#{@tmp_file.path}'`
    end
  end
end