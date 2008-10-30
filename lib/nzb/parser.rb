require 'rexml/document'
require 'rexml/streamlistener'
require 'nzb/file'

class NZB
  class Parser
    include REXML::StreamListener
    
    attr_reader :files
    
    def initialize(nzb)
      @nzb = nzb
      @files = []
      ::File.open(@nzb.path) do |nzb_file|
        REXML::Document.parse_stream(nzb_file, self)
      end
    end
    
    def tag_start(name, attributes)
      case name
      when 'file'
        @files << NZB::File.new(@nzb, attributes)
      when 'segment'
        @segment = @files.last.add_segment(attributes)
      end
    end
    
    def text(text)
      @segment.message_id = text.strip and @segment = nil if @segment
    end
  end
end