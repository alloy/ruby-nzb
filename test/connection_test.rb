require File.expand_path('../test_helper', __FILE__)
require 'nzb'
require 'nzb/connection'

describe "The NZB::Connection class methods" do
  before do
    NZB.queue(fixture('small.nzb'))
  end
  
  after do
    NZB.clear_queue!
    NZB.blocking = false
  end
  
  it "should start an EventMachine runloop" do
    NZB.blocking = true
    Thread.expects(:new).never
    EventMachine.expects(:run)
    NZB::Connection.start_eventmachine_runloop! {}
  end
  
  it "should not start a second EventMachine runloop" do
    EventMachine.stubs(:reactor_running?).returns(true)
    EventMachine.expects(:run).never
    NZB::Connection.start_eventmachine_runloop! {}
  end
  
  it "should start an EventMachine runloop in a new thread if it should not be blocking" do
    NZB.blocking = false
    Thread.expects(:new)
    NZB::Connection.start_eventmachine_runloop! {}
  end
  
  it "should start the EventMachine runloop when starting the pool" do
    NZB::Connection.expects(:start_eventmachine_runloop!)
    NZB::Connection.start_pool!
  end
  
  it "should start a pool of connections" do
    EventMachine.stubs(:run)
    NZB::Connection.instance_variable_set(:@pool, nil)
    
    NZB.setup(:host => 'news.example.com', :blocking => false)
    NZB::Connection.expects(:connect).with('news.example.com', 119).times(1).returns('connection')
    NZB::Connection.start_pool!
    NZB::Connection.pool.should == %w{ connection }
    
    NZB::Connection.instance_variable_set(:@pool, nil)
    
    NZB.setup(:host => 'news.example.com', :pool_size => 2, :port => 1119, :blocking => false)
    NZB::Connection.expects(:connect).with('news.example.com', 1119).times(2).returns('connection')
    NZB::Connection.start_pool!
    NZB::Connection.pool.should == %w{ connection connection }
  end
  
  it "should fill the pool up to the maximum" do
    NZB.queue(fixture('ubuntu.nzb'))
    
    NZB.stubs(:pool_size).returns(4)
    NZB::Connection.pool.clear
    NZB::Connection.stubs(:start_eventmachine_runloop!).yields
    
    NZB::Connection.expects(:connect).returns('connection').times(6)
    
    NZB::Connection.start_pool!
    NZB::Connection.pool.should == Array.new(4) { 'connection' }
    
    2.times { NZB::Connection.pool.pop }
    
    NZB::Connection.start_pool!
    NZB::Connection.pool.should == Array.new(4) { 'connection' }
  end
  
  it "should not fill up the pool more than necessary" do
    NZB.stubs(:pool_size).returns(4)
    NZB::Connection.pool.clear
    
    NZB::Connection.expects(:connect).returns('connection').times(2)
    NZB::Connection.fill_pool!
    NZB::Connection.pool.should == Array.new(2) { 'connection' }
  end
  
  it "should start an EventMachine PeriodicTimer which checks if we are using all available connections in blocking mode" do
    NZB.blocking = true
    EventMachine.stubs(:run).yields
    EventMachine::PeriodicTimer.expects(:new).with(2).yields
    NZB::Connection.expects(:fill_pool!)
    NZB::Connection.start_eventmachine_runloop! {}
  end
  
  it "should start an EventMachine PeriodicTimer which checks if we are using all available connections in non blocking mode" do
    NZB.blocking = false
    Thread.stubs(:new).yields
    EventMachine.stubs(:run).yields
    EventMachine::PeriodicTimer.expects(:new).with(2).yields
    NZB::Connection.expects(:fill_pool!)
    NZB::Connection.start_eventmachine_runloop! {}
  end
end

describe "A NZB::Connection instance, when receiving data" do
  before do
    @connection = NZB::Connection.new(nil)
    @connection.stubs(:send_data)
    #@connection.stubs(:close_connection)
    
    @file = NZB::File.new(nil)
    @file.add_segment('message_id' => '1', 'bytes' => '1')
    @file.add_segment('message_id' => '2', 'bytes' => '2')
    NZB::Parser.any_instance.stubs(:files).returns([@file])
    
    @nzb = NZB.new(fixture('small.nzb'))
    @file.instance_variable_set(:@nzb, @nzb)
    NZB.stubs(:request_file).returns(@file)
    @file.stubs(:post_process!)
    
    @connection.request_job
  end
  
  it "should not be ready after initialization" do
    @connection.should.not.be.ready
    @connection.should.not.be.receiving_body_data
  end
  
  it "should act appropriately on the received status codes" do
    @connection.expects(:connection_ready).with('news.tweakdsl.nl NNRP Service Ready - info@tweakdsl.nl (posting ok).')
    @connection.receive_data("200 news.tweakdsl.nl NNRP Service Ready - info@tweakdsl.nl (posting ok).\r\n")
    
    @connection.expects(:receive_body_data).with("Some\r\nData\r\n")
    @connection.receive_data("222 0 <1224548665.67924.23@europe.news.astraweb.com> body\r\nSome\r\nData\r\n")
    @connection.should.be.receiving_body_data
  end
  
  it "should log any status codes that are unimplemented" do
    @connection.logger.expects(:error).with("Connection [#{@connection.object_id}]: UNIMPLEMENTED STATUS CODE: 430 - no such article")
    @connection.receive_data("430 no such article\r\n")
  end
  
  it "should request a job when the connection becomes ready" do
    @connection.expects(:request_job)
    @connection.connection_ready('news.example.com')
  end
  
  it "should set the name of the file on the NZB::File instance when received the data describing the segment" do
    @connection.receive_data("222 0 <1224548665.67924.23@europe.news.astraweb.com> body\r\n=ybegin line=128 size=123456 name=foo.rar\r\nSome\r\nData\r\n")
    @file.name.should == 'foo.rar'
  end
  
  it "should keep passing on data to receive_body_data while receiving_body_data?" do
    @connection.receive_data("222 0 <1224548665.67924.23@europe.news.astraweb.com> body\r\nSome\r\nData\r\n")
    @connection.receive_data("And\r\nSome\r\nMore\r\nData\r\n")
    @connection.received_data.should == "Some\r\nData\r\nAnd\r\nSome\r\nMore\r\nData\r\n"
  end
  
  it "should call segment_completed when the end of a multi part message has been reached" do
    @connection.instance_variable_set(:@receiving_body_data, true)
    @connection.expects(:segment_completed)
    @connection.receive_data("Some\r\Last\r\nData\r\n.\r\n")
    @connection.received_data.should == "Some\r\Last\r\nData\r\n.\r\n"
    @connection.should.not.be.receiving_body_data
  end
  
  it "should call segment_completed when the end of a single part message has been reached" do
    @connection.expects(:segment_completed)
    @connection.receive_data("222 blah\r\nSome\r\Last\r\nData\r\n.\r\n")
    @connection.received_data.should == "Some\r\Last\r\nData\r\n.\r\n"
    @connection.should.not.be.receiving_body_data
  end
  
  it "should pass all received_data back to the NZB::File instance when the segment completed and request a new job" do
    @connection.instance_variable_set(:@received_data, "Some\r\nData\r\n.\r\n")
    @connection.current_file.expects(:write_data).with("Some\r\nData\r\n.\r\n")
    @connection.expects(:request_job)
    @connection.segment_completed
    @connection.received_data.should == ''
  end
  
  it "should set the current file to nil when done with a segment and the file is done too" do
    @connection.stubs(:request_job)
    @connection.current_file.stubs(:done?).returns(true)
    @connection.segment_completed
    @connection.current_file.should.be nil
  end
  
  it "should not set the current file to nil when done with a segment but the file isn't done yet" do
    @file.stubs(:done?).returns(false)
    @connection.segment_completed
    @connection.current_file.should.be @file
  end
  
  xit "should unescape the data" do
    
  end
end