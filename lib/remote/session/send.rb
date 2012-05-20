module Remote

  class Session
  
    class Send

      attr_accessor :remote_path
      attr_accessor :chunk_size

      def initialize( remote_path )
        @remote_path = remote_path
        @chunk_size  = 1024
        @file        = nil
      end

      def read
        open if ! open?
        
        @file.read( @chunk_size )
      end

      def eof?
        return true if ! open?
        @file.eof?
      end

      def open?
        ! @file.nil?
      end

      def open
        if open?
          @file.rewind
          return
        end

        _open
      end

      def close
        return if ! open?
        @file.close
        @file = nil
      end

    end

  end

end

