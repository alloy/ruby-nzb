require File.expand_path('../test_helper', __FILE__)
require 'nzb'
require 'nzb/connection'

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
    puts "Server: #{str}"
  end
end

describe "NZB::Connection" do
  before do
    @nzb = NZB.queue(fixture('small.nzb'))
  end
  
  after do
    NZB.clear_queue!
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
    data = "=yenc begin\r\nSome yEnc encoded data from segment %s\r\n=yenc end\r\n.\r\n"
    
    message_ids = %w{ file-1@segment-1 file-1@segment-2 file-2@segment-1 file-2@segment-2 }
    responses = message_ids.inject({}) do |hash, message_id|
      hash[message_id] = data % message_id
      hash
    end
    
    message_ids.first(2).each do |message_id|
      @nzb.files.first.expects(:write_data).with(responses[message_id])
    end
    
    message_ids.last(2).each do |message_id|
      @nzb.files.last.expects(:write_data).with(responses[message_id])
    end
    
    connect! :responses => responses
  end
  
  it "should close if there are no more jobs" do
    NZB.clear_queue!
    NZB::Connection.any_instance.expects(:close_connection)
    connect!
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