require File.expand_path('../test_helper', __FILE__)
require 'nzb'
require 'nzb/connection'

#ENV['LOG_DATA'] = 'true' if $0 == __FILE__

class TestNNTPServer < EM::Connection
  Localhost = "127.0.0.1"
  Localport = 1119
  
  attr_reader :received
  
  def initialize(*args)
    @options = { :send_server_greeting => true, :responses => {} }.merge(args.pop)
    @received = ""
    super
  end
  
  def post_init
    (EM.spawn { |x| x.send_server_greeting }).notify(self) if @options[:send_server_greeting]
  end
  
  SERVER_GREETING = "200 news.localhost\r\n"
  def send_server_greeting
    log "Send greeting: #{SERVER_GREETING}"
    send_data SERVER_GREETING
  end
  
  def receive_data(data)
    log "Receive data: #{data}"
    @received << data
    
    message_id = data.scan(/BODY <(.+)>\r\n/).flatten.first
    if response = @options[:responses][message_id]
      log "Send response: #{response}"
      send_data response
    end
  end
  
  def unbind
    log "Closing"
  end
  
  def log(str)
    puts "Server: #{str}" if ENV['LOG_DATA'] == 'true'
  end
end

describe "NZB::Connection" do
  before do
    @nzb = NZB.queue(fixture('small.nzb'))
  end
  
  after do
    NZB.clear_queue!
    NZB.blocking = false
  end
  
  it "should not be ready when we haven't received a server greeting yet" do
    NZB.clear_queue!
    connect! :send_server_greeting => false
    connection.should.not.be.ready
  end
  
  it "should be ready when we have received a server greeting" do
    NZB.clear_queue!
    connect!
    connection.should.be.ready
  end
  
  it "should request a job from the NZB queue" do
    connect!
    server.received.should == "BODY <#{@nzb.files.first.segments.first.message_id}>\r\n"
  end
  
  it "should send the received data back to the NZB::File instance that's being processed, once a full segment has been received" do
    data = "=yenc begin\r\nSome yEnc encoded data from segment %s\r\n..This double dot should become one.. However that last double dot should stay.\r\n=yenc end\r\n.\r\n"
    
    message_ids = %w{ file-1@segment-1 file-1@segment-2 file-2@segment-1 file-2@segment-2 }
    responses = message_ids.inject({}) do |hash, message_id|
      hash[message_id] = data % message_id
      hash
    end
    
    message_ids.first(2).each do |message_id|
      @nzb.files.first.expects(:write_data).with do |data|
        data == responses[message_id].sub(/\r\n\.\./, "\r\n.")
      end
    end
    
    message_ids.last(2).each do |message_id|
      @nzb.files.last.expects(:write_data).with do |data|
        data == responses[message_id].sub(/\r\n\.\./, "\r\n.")
      end
    end
    
    connect! :responses => responses
  end
  
  it "should close if there are no more jobs" do
    NZB.clear_queue!
    NZB::Connection.any_instance.expects(:close_connection)
    connect!
  end
  
  it "should report that it's closing" do
    NZB.clear_queue!
    connect! do
      NZB::Connection.pool << connection
    end
    NZB::Connection.pool.should.not.include connection
  end
  
  it "should requeue the currently processing NZB::File instance if the connection terminated unexpectedly" do
    connect! do
      def connection.receive_data(data)
        if @second_time
          close_connection
        else
          @second_time = true
          super
        end
      end
    end
    @nzb.request_file.should == @nzb.files.first
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
  
  private
  
  attr_reader :server, :connection
  
  def connect!(options = {})
    timeout = options.delete(:timeout) || 1
    
    EM.run do
      EM::Timer.new(timeout) { EM.stop }
      EM.start_server(TestNNTPServer::Localhost, TestNNTPServer::Localport, TestNNTPServer, options) { |server| @server = server }
      @connection = NZB::Connection.connect(TestNNTPServer::Localhost, TestNNTPServer::Localport)
      yield if block_given?
    end
  end
end