require 'nzb/segment'
require 'tempfile'

class NZB
  class File
    attr_reader :nzb, :segments, :queue, :processing, :tmp_file, :downloaded_bytes
    
    def initialize(nzb)
      @nzb = nzb
      @segments, @queue = [], []
      @downloaded_bytes = 0
    end
    
    def ==(other)
      @segments == other.segments
    end
    
    def done?
      @queue.empty?
    end
    
    def bytes
      @bytes ||= @segments.inject(0) { |sum, segment| sum += segment.bytes }
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
      
      @downloaded_bytes += data.length
      @nzb.run_update_callback!
      
      if done?
        @tmp_file.close
        post_process!
      end
    end
    
    # For now we fork to not stall the runloop. This might not work so great in a RubyCocoa app...
    def post_process!
      Process.detach(fork do
        `uudeview -i -p '#{@nzb.output_directory}' '#{@tmp_file.path}'`
        ::File.unlink(@tmp_file.path)
      end)
    end
  end
end