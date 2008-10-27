require File.expand_path('../test_helper', __FILE__)
require 'nzb/file'

describe "NZB::File" do
  before do
    @nzb = stub('NZB')
    @nzb.stubs(:run_update_callback!)
    
    @file = NZB::File.new(@nzb)
    @file.add_segment('message_id' => '1', 'bytes' => '1')
    @file.add_segment('message_id' => '2', 'bytes' => '2')
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
  
  it "should decode the file segments that were written to the tmp file and remove it and let the NZB instance know there was an update" do
    @file.write_data "Some data\r\n"
    tmp_file = @file.tmp_file.path
    nzb = mock('NZB')
    
    @file.stubs(:done?).returns(true)
    @file.instance_variable_set(:@nzb, nzb)
    nzb.stubs(:output_directory).returns('/final/destination')
    
    Thread.class_eval do
      class << self
        alias_method :new_before_test, :new
        def new
          yield
        end
      end
    end
    
    @file.expects(:`).with("uudeview -i -p '/final/destination' '#{tmp_file}' > /dev/null 2>&1")
    
    nzb.expects(:run_update_callback!)
    
    @file.write_data "Some more data\r\n"
    File.should.not.exist tmp_file
    
    Thread.class_eval do
      class << self
        alias_method :new, :new_before_test
      end
    end
  end
  
  it "should return wether or not it's done" do
    @file.segments.length.times { @file.request_job }
    @file.queue.should.be.empty
    @file.should.be.done
  end
  
  it "should return the total amount of bytes of all segments" do
    @file.bytes.should == 3
  end
  
  it "should keep track of the amount of bytes that were downloaded and written to the tmp file" do
    @file.write_data "12345678\r\n12345678\r\n"
    @file.downloaded_bytes.should == 20
  end
end
