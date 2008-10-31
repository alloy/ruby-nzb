class NZB
  class File
    class << self
      def file_types
        @file_types ||= {}
      end
      
      def file_type(name, regexp)
        file_types[name] = regexp
        class_eval do
          define_method("#{name}?") do
            guess_file_type == name
          end
        end
      end
    end
    
    def guess_file_type
      if @guessed_file_type.nil? && match = self.class.file_types.find { |_, regexp| @subject =~ regexp }
        @guessed_file_type = match.first
      end
      @guessed_file_type
    end
    
    # Rar
    file_type :rar,  /\.rar/
    
    # Par2
    file_type :par2, /\.par2/
    
    PAR2_BLOCKS_REGEXP = /vol\d+\+(\d+)\.PAR2/
    file_type :par2_blocks, PAR2_BLOCKS_REGEXP
    
    def number_of_par2_blocks
      @number_of_par2_blocks ||= (par2_blocks? ? (@subject.match(PAR2_BLOCKS_REGEXP)[1].to_i) : 0)
    end
  end
end