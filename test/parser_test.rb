require File.expand_path('../test_helper', __FILE__)
require 'nzb/parser'
require 'stringio'

describe "NZB::Parser" do
  before do
    @message_ids = %w{
      48f8511f$0$16961$426a74cc@news.free.fr
      48f85129$0$16961$426a74cc@news.free.fr
      48f85132$0$16961$426a74cc@news.free.fr
    }
    
    xml = %{
      <?xml version="1.0" encoding="iso-8859-1"?>
      <!DOCTYPE nzb PUBLIC "-//newzBin//DTD NZB 0.9//EN" "http://www.newzbin.com/DTD/nzb/nzb-0.9.dtd">
      <nzb xmlns="http://www.newzbin.com/DTD/2003/nzb">
        <file poster="Yenc@power-post.org Yenc-PP-A&amp;A" date="1224233256" subject="File with 1 segment">
          <segments>
            <segment bytes="258635" number="1">#{@message_ids.first}</segment>
          </segments>
        </file>
        <file poster="Yenc@power-post.org Yenc-PP-A&amp;A" date="1224233256" subject="File with 3 segments">
          <segments>
            <segment bytes="258635" number="1">#{@message_ids[0]}</segment>
            <segment bytes="258635" number="2">#{@message_ids[1]}</segment>
            <segment bytes="258635" number="3">#{@message_ids[2]}</segment>
          </segments>
        </file>
      </nzb>
    }
    
    @data = StringIO.new(xml, 'r')
    File.stubs(:open).with('/some/file.nzb').yields(@data)
    @parser = NZB::Parser.new('/some/file.nzb')
  end
  
  after do
    @data.close
  end
  
  it "should have parsed the correct files and segments" do
    @parser.files.should == [
      [@message_ids.first],
      @message_ids
    ]
  end
end

describe "NZB::Parser, with a real NZB file" do
  before do
    @path = fixture('ubuntu.nzb')
    @parser = NZB::Parser.new(@path)
  end
  
  it "should have parsed the correct amount of files" do
    @parser.files.length.should == number_of_files
  end
  
  it "should have parsed the correct amount of segments" do
    @parser.files.inject(0) { |sum, segments| sum += segments.length }.should == number_of_segments
  end
  
  private
  
  def number_of_files
    `cat #{@path} | grep '</file>'`.split("\n").length
  end
  
  def number_of_segments
    `cat #{@path} | grep '</segment>'`.split("\n").length
  end
end