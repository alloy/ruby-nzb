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
      puts "Done post processing file!"
    end
    
    # For now we fork to not stall the runloop. This might not work so great in a RubyCocoa app...
    def post_process!
      # EventMachine.spawn do |file, output_directory, tmp_file|
      #   puts 'post_process!'
      #   
      #   output = `uudeview -i -d -p '#{output_directory}' '#{tmp_file}' 2>&1`
      #   case output
      #   when /File successfully written/m, /Note: No encoded data found/m
      #     puts 'File successfully written'
      #   else
      #     puts "Unknown uudeview output: #{output.inspect}"
      #   end
      #   ::File.unlink(tmp_file)
      #   #file.done_post_processing(output)
      # end.notify(self, @nzb.output_directory, @tmp_file.path)
      
      Thread.new do
        output = `uudeview -i -d -p '#{@nzb.output_directory}' '#{@tmp_file.path}' 2>&1`
        case output
        when /File successfully written/m, /Note: No encoded data found/m
          puts 'File successfully written'
        else
          puts "Unknown uudeview output: #{output.inspect}"
        end
        ::File.unlink(@tmp_file.path)
      end
    end
  end
end