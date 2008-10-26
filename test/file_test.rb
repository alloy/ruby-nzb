require File.expand_path('../test_helper', __FILE__)
require 'nzb/file'

describe "NZB::File" do
  before do
    @file = NZB::File.new
  end
  
  it "should add a segment" do
    @file.add_segment('message_id' => '1')
    @file.add_segment('message_id' => '2')
    
    @file.segments.should == [
      NZB::File::Segment.new('message_id' => '1'),
      NZB::File::Segment.new('message_id' => '2')
    ]
  end
end
