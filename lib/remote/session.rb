require 'remote/session/send_file'
require 'remote/session/version'
require 'net/sftp'
require 'net/ssh'
require 'base64'

module Remote
  class Session
    SUDO_PROMPT = 'sudo_prompt'

    def self.open( host, options = {}, &block )
      rs = new( host, options )

      block.call rs

      rs.close
    end

    attr_accessor :host
    attr_accessor :username
    attr_accessor :password
    attr_accessor :port
    attr_accessor :private_key
    attr_accessor :prompts
    attr_accessor :session

    def initialize( host, options = {} )
      @session       = nil
      @host          = host
      @username      = options[ :username      ] || ENV[ 'USER' ]
      @password      = options[ :password      ]
      @port          = options[ :port          ]
      @private_key   = options[ :private_key   ]
      @prompts       = options[ :prompts       ] || {}
      @sudo_password = options[ :sudo_password ]

      connect
    end

    def run( command )
      raise "Session is closed" if @session.nil?
      puts "@#{ @host }: #{ command }"
      puts @session.exec!( command )
    end

    def sudo( commands )
      raise "Session is closed" if @session.nil?
      commands = [ *commands ]

      @session.open_channel do |ch|
        ch.request_pty do |ch, success|
          raise "Could not obtain pty" if ! success

          channel_exec ch, commands
        end
      end
      @session.loop
    end

    def close
      @session.close
      @session = nil
    end

    def put( remote_path, &block )
      sftp = Net::SFTP::Session.new( @session ).connect!
      sftp.file.open( remote_path, 'w' ) do |f|
        f.write block.call
      end
      sftp.close_channel
    end

    private

    def ssh_options
      s = {}
      s[ :password ] = @password        if @password
      s[ :keys     ] = [ @private_key ] if @private_key
      s[ :port     ] = @port            if @port
      s
    end

    def connect
      @session = Net::SSH.start( @host, @username, ssh_options )
    end

    def channel_exec( ch, commands )
      ch[ :commands ] = commands

      ch.exec "sudo -k -p '#{ SUDO_PROMPT }' su -" do |ch, success|
        raise "Could not execute sudo su command" if ! success

        ch.on_data( &method( :on_data ) )

        ch.on_extended_data do |ch, type, data|
          $stderr.puts data
        end
      end
    end

    def on_data( ch, data )
      if data =~ Regexp.new( SUDO_PROMPT )
        ch.send_data "#{ @sudo_password }\n"
        return
      end

      @prompts.each_pair do | prompt, send |
        if data =~ Regexp.new( prompt )
          ch.send_data "#{ send }\n"
          return
        end
      end

      $stdout.write( data )

      if ch[ :commands ].size == 0
        ch.send_data "exit\n"
        return
      end

      command = ch[ :commands ].shift
      if command.is_a?( Remote::Session::SendFile )
        send_file_chunk( ch, command )
      else
        ch.send_data "#{command}\n"
      end
    end

    def send_file_chunk( ch, send_file )
      if send_file.open?
        operator = '>>'
      else
        send_file.open
        operator = '>'
      end

      chunk =
        if ! send_file.eof?
          Base64.encode64( send_file.read )
        else
          # Handle empty files
          ''
        end
      ch.send_data "echo -n '#{ chunk }' | base64 -d #{ operator } #{ send_file.remote_path }\n"

      if send_file.eof?
        send_file.close
      else
        ch[ :commands ].unshift send_file
      end
    end

  end
end

