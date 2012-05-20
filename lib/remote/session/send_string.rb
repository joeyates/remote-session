require 'stringio'

module Remote

  class Session

    class SendString < Send

      attr_accessor :string

      def initialize( string, remote_path )
        @string = string
        super( remote_path )
      end

      private

      def _open
        @file = StringIO.new( @string )
      end
      
    end
    
  end

end

