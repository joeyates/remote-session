module Remote

  class Session

    class SendFile

      attr_accessor :local_path
      attr_accessor :remote_path
      attr_accessor :chunk_size

      def initialize( local_path, remote_path )
        @local_path  = local_path
        @remote_path = remote_path
        @chunk_size  = 1024
        @file        = nil
      end

      def open?
        ! @file.nil?
      end

      def eof?
        return true if ! open?
        @file.eof?
      end

      def read
        open if ! open?
        
        @file.read( @chunk_size )
      end

      def close
        return if ! open?
        @file.close
        @file = nil
      end

      def open
        close if open?
        @file = File.open( @local_path, 'r' )
      end

    end

  end

end

