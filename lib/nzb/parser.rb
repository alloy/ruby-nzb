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
    
    def tag_start(name, attrs)
      case name
      when 'segments'
        @files << NZB::File.new(@nzb)
      when 'segment'
        @segment = @files.last.add_segment(attrs)
      end
    end
    
    def text(text)
      @segment.message_id = text.strip and @segment = nil if @segment
    end
  end
end