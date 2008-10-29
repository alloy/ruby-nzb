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
    
    def requeue!
      @queue.unshift @processing
      @processing = nil
      @nzb.requeue self
    end
    
    def write_data(data)
      @tmp_file ||= Tempfile.new(object_id, ::File.join(@nzb.work_directory))
      @tmp_file.write(data)
      
      # FIXME: This is cheating, as we use the bytes from the segment,
      # rather then data.length. There's a discrepancy between the bytes
      # from the nzb xml file and what we actually get.
      # For now it's good enough.
      @downloaded_bytes += @processing.bytes
      
      # FIXME: This might need to be spawned
      @nzb.run_update_callback!
      
      if done?
        @tmp_file.close
        post_process!
      end
    end
    
    def done_post_processing(output)
      ::File.unlink(@tmp_file.path)
      
      logger.info "Done post processing file!"
      case output
      when /File successfully written/m, /Note: No encoded data found/m
        logger.info 'File successfully written'
      else
        logger.error "Unknown uudeview output: #{output.inspect}"
      end
    end
    
    def post_process!
      process = lambda { `uudeview -i -d -p '#{@nzb.output_directory}' '#{@tmp_file.path}' 2>&1` }
      callback = lambda { |output| done_post_processing(output) }
      EventMachine.defer(process, callback)
    end
  end
end