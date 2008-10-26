require File.expand_path('../test_helper', __FILE__)
require 'nzb'

describe "NZB class" do
  before do
    NZB.queue fixture('ubuntu.nzb')
  end
  
  after do
    NZB.clear_queue!
  end
  
  it "should have added a new NZB to the queue" do
    NZB.queued.last.path.should == fixture('ubuntu.nzb')
  end
  
  it "should clear the queue" do
    NZB.clear_queue!
    NZB.queued.should.be.empty
  end
  
  it "should return a file" do
    NZB.request_file.should == NZB.queued.last.files.first
  end
end

describe "NZB instance" do
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
  
  it "should return a file to be downloaded from the queue" do
    @nzb.request_file.should == @nzb.files.first
    @nzb.queue.should == [@nzb.files.last]
  end
  
  xit "should advance to the next file if the current one is done" do
  end
end