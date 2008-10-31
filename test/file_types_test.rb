require File.expand_path('../test_helper', __FILE__)
require 'nzb/file'

describe "A NZB::File instance, when asked to guess the file type from the subject" do
  before do
    @nzb = NZB.new(fixture('large.nzb'))
    
    # @nzb.files.each_with_index do |file, index|
    #   p index, file.subject if file.subject.include?('PAR2')
    # end
  end
  
  it "should return :rar for the extension `rar'" do
    @nzb.files[1].guess_file_type.should == :rar
    @nzb.files[1].should.be.rar
  end
  
  it "should return :par2 for the extension `par2'" do
    @nzb.files[0].guess_file_type.should == :par2
    @nzb.files[0].should.be.par2
  end
  
  it "should return :par2_blocks for an extension matching `vol001+002.PAR2'" do
    @nzb.files[18].guess_file_type.should == :par2_blocks
    @nzb.files[18].should.be.par2_blocks
  end
  
  it "should store the amount of par2 blocks in the file" do
    @nzb.files[18].par2?
    @nzb.files[18].number_of_par2_blocks.should.be 2
    
    @nzb.files[19].par2?
    @nzb.files[19].number_of_par2_blocks.should.be 4
    
    @nzb.files[20].par2?
    @nzb.files[20].number_of_par2_blocks.should.be 8
  end
end