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
    
    @path = '/some/file.nzb'
    @data = StringIO.new(xml, 'r')
    File.stubs(:open).with(@path).yields(@data)
    @nzb = stub('NZB')
    @nzb.stubs(:path).returns(@path)
    @parser = NZB::Parser.new(@nzb)
  end
  
  after do
    @data.close
  end
  
  it "should have parsed the correct files and segments" do
    file_with_1_segment = NZB::File.new(nil)
    file_with_1_segment.add_segment('message_id' => @message_ids.first)
    
    file_with_3_segments = NZB::File.new(nil)
    @message_ids.each { |id| file_with_3_segments.add_segment('message_id' => id) }
    
    @parser.files.should == [file_with_1_segment, file_with_3_segments]
  end
  
  it "should have initialized all NZB::File instances with the NZB instance as their owner" do
    @parser.files.all? { |file| file.nzb == @nzb }.should.be true
  end
  
  it "should have parsed out the subjects" do
    @parser.files.map { |file| file.subject }.should == ['File with 1 segment', 'File with 3 segments']
  end
end

describe "NZB::Parser, with a real NZB file" do
  before do
    @path = fixture('ubuntu.nzb')
    @nzb = stub('NZB')
    @nzb.stubs(:path).returns(@path)
    @parser = NZB::Parser.new(@nzb)
  end
  
  it "should have parsed the correct amount of files" do
    @parser.files.length.should == 2
  end
  
  it "should have parsed the correct amount of segments" do
    (@parser.files.first.segments.length + @parser.files.last.segments.length).should == 202
  end
end