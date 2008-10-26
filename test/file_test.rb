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
  
  it "should return a segment to be processed" do
    @file.request_job.should == @file.segments.first
    @file.processing.should == @file.segments.first
    @file.queue.should == [@file.segments.last]
  end
  
  it "should return wether or not it's done" do
    @file.segments.length.times { @file.request_job }
    @file.queue.should.be.empty
    @file.should.be.done
  end
end
