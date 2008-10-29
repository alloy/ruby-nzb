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