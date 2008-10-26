require File.expand_path('../test_helper', __FILE__)
require 'nzb'

describe "NZB" do
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
end