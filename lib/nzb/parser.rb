require 'rexml/document'
require 'rexml/streamlistener'

class NZB
  class Parser
    include REXML::StreamListener
    
    attr_reader :files
    
    def initialize(path)
      @files = []
      File.open(path) do |nzb|
        REXML::Document.parse_stream(nzb, self)
      end
    end
    
    def tag_start(name, attrs)
      if name == 'segments'
        @record_text = true
        @files << []
      end
    end
    
    def tag_end(name)
      @record_text = false if name == 'segments'
    end
    
    def text(text)
      return if !@record_text || text.strip.empty?
      @files.last << text
    end
  end
end