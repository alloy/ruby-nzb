require File.expand_path('../test_helper', __FILE__)
require 'nzb/connection'

class TestNNTPServer < EM::Connection
  Localhost = "127.0.0.1"
  Localport = 1119
  
  def initialize(*args)
    @options = { :send_server_greeting => true }.merge(args.pop)
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
  
  def unbind
    log "Closing"
  end
  
  def log(str)
    puts "Server: #{str}"
  end
end

describe "NZB::Connection" do
  it "should not be ready when we haven't received a server greeting yet" do
    connect! :send_server_greeting => false
    connection.should.not.be.ready
  end
  
  it "should be ready when we haven't received a server greeting yet" do
    connect!
    connection.should.be.ready
  end
  
  private
  
  attr_reader :connection
  
  def connect!(options = {})
    timeout = options.delete(:timeout) || 1
    
    EM.run do
      EM.start_server(TestNNTPServer::Localhost, TestNNTPServer::Localport, TestNNTPServer, options)
      EM::Timer.new(timeout) { EM.stop }
      
      @connection = NZB::Connection.connect(TestNNTPServer::Localhost, TestNNTPServer::Localport)
      
      yield if block_given?
    end
  end
end