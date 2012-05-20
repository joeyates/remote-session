module Remote

  class Session

    class SendFile < Send

      attr_accessor :local_path

      def initialize( local_path, remote_path )
        @local_path  = local_path
        super( remote_path )
      end

      private

      def _open
        @file = File.open( @local_path, 'r' )
      end

    end

  end

end

