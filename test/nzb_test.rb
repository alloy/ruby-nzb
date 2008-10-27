require File.expand_path('../test_helper', __FILE__)
require 'nzb'

describe "NZB class" do
  before do
    @nzb = NZB.queue(fixture('ubuntu.nzb'))
  end
  
  after do
    NZB.clear_queue!
  end
  
  it "should take required and optional parameters to setup NZB" do
    NZB.setup(:host => 'news.example.com')
    NZB.host.should == 'news.example.com'
    NZB.output_directory.should == TMP_DIR
    NZB.port.should == 119
    NZB.pool_size.should == 1
    NZB.blocking.should == true
    
    NZB.setup(:port => 1119, :pool_size => 4, :blocking => false)
    NZB.host.should == 'news.example.com'
    NZB.output_directory.should == TMP_DIR
    NZB.port.should == 1119
    NZB.pool_size.should == 4
    NZB.blocking.should == false
  end
  
  it "should add a new NZB to the queue" do
    nzb = NZB.queue(fixture('ubuntu.nzb'))
    nzb.path.should == fixture('ubuntu.nzb')
    NZB.queued.last.should.be nzb
  end
  
  it "should return a file" do
    NZB.request_file.should == NZB.queued.last.files.first
  end
  
  it "should advance to the next NZB when the current one is done" do
    @nzb.stubs(:done?).returns(true)
    new_nzb = NZB.queue(fixture('small.nzb'))
    NZB.request_file.should == new_nzb.files.first
  end
  
  it "should clear the queue" do
    NZB.clear_queue!
    NZB.queued.should.be.empty
    NZB.request_file.should.be nil
  end
end

describe "NZB instance" do
  before do
    @nzb = NZB.new(fixture('ubuntu.nzb'))
  end
  
  after do
    FileUtils.rm_rf(TMP_DIR)
  end
  
  it "should initialize with a path to a NZB xml file" do
    @nzb.path.should == fixture('ubuntu.nzb')
  end
  
  it "should return the working directory" do
    @nzb.output_directory.should == File.join(TMP_DIR, 'ubuntu')
  end
  
  it "should have created the working directory" do
    File.should.exist @nzb.output_directory
    File.should.be.directory @nzb.output_directory
  end
  
  it "should have parsed the files/segments from the NZB xml file" do
    @nzb.files.length.should == 2
    (@nzb.files.first.segments.length + @nzb.files.last.segments.length).should == 202
  end
  
  it "should return a file to be downloaded from the queue" do
    @nzb.request_file.should == @nzb.files.first
    @nzb.queue.should == [@nzb.files.last]
  end
  
  it "should be done when the queue is empty" do
    @nzb.queue.clear
    @nzb.should.be.done
  end
  
  it "should take a on_update callback" do
    counter = 0
    
    @nzb.on_update do |nzb|
      nzb.should.be @nzb
      counter += 1
    end
    @nzb.run_update_callback!
    
    counter.should.be 1
  end
  
  it "should not actually call the on_update callback if there is none" do
    lambda { @nzb.run_update_callback! }.should.not.raise
  end
end