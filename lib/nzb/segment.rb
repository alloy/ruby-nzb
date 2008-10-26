class NZB
  class File
    class Segment
      attr_accessor :message_id, :number, :bytes
      
      def initialize(attributes)
        @message_id = attributes['message_id']
        @number = attributes['number']
        @bytes = attributes['bytes']
      end
      
      def ==(other)
        @message_id == other.message_id
      end
    end
  end
end