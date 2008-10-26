require File.expand_path('../test_helper', __FILE__)
require 'nzb'

describe "NZB" do
  before do
    @nzb = NZB.new(fixture('ubuntu.nzb'))
  end
  
  it "should initialize with a path to a NZB xml file" do
    @nzb.path.should == fixture('ubuntu.nzb')
  end
  
  it "should have parsed the files/segments from the NZB xml file" do
    @nzb.files.length.should == 2
    (@nzb.files.first.segments.length + @nzb.files.last.segments.length).should == 202
  end
  
  it "should return a segment to be downloaded mark the file as “processing”" do
    @nzb.request_segment_job.should == @nzb.files.first.segments.first
    @nzb.queue.should == [@nzb.files.last]
    @nzb.processing.should == @nzb.files.first
  end
  
  xit "should advance to the next file if the current one is done" do
  end
end