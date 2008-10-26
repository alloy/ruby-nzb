require File.expand_path('../test_helper', __FILE__)
require 'nzb/segment'

describe "NZB::File::Segment" do
  before do
    @segment = NZB::File::Segment.new('message_id' => 'id')
  end
  
  it "should take a message id as it's constructor argument" do
    @segment.message_id.should == 'id'
  end
  
  it "should be possible to set the message id after initialization" do
    @segment.message_id = 'another id'
    @segment.message_id.should == 'another id'
  end
end