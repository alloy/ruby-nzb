require File.expand_path('../test_helper', __FILE__)
require 'nzb/file'

describe "NZB::File" do
  before do
    @file = NZB::File.new
    @file.add_segment('message_id' => '1')
    @file.add_segment('message_id' => '2')
  end
  
  it "should add a segment" do
    @file.segments.should == [
      NZB::File::Segment.new('message_id' => '1'),
      NZB::File::Segment.new('message_id' => '2')
    ]
  end
  
  it "should not have an open file stream to a tmp file after initialization" do
    @file.tmp_file.should.be nil
  end
  
  it "should return a segment to be processed" do
    @file.request_job.should == @file.segments.first
    @file.processing.should == @file.segments.first
    @file.queue.should == [@file.segments.last]
  end
  
  it "should initialize a tmp file instance if it doesn't exist yet and write data to it" do
    @file.write_data "Some data\r\n"
    @file.tmp_file.rewind
    @file.tmp_file.gets.should == "Some data\r\n"
  end
  
  it "should return wether or not it's done" do
    @file.segments.length.times { @file.request_job }
    @file.queue.should.be.empty
    @file.should.be.done
  end
end
