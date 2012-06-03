require 'remote/session/send'
require 'remote/session/send_file'
require 'remote/session/send_string'
require 'remote/session/version'
require 'net/sftp'
require 'net/ssh'
require 'base64'

module Remote
  class Session
    SUDO_PASSWORD_PROMPT = 'remote-session-sudo-prompt'
    ROOT_COMMAND_PROMPT  = 'remote-session-prompt#'
    ROOT_COMMAND_PROMPT_MATCH = /#{ ROOT_COMMAND_PROMPT }$/

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

      ch.exec "sudo -k -p '#{ SUDO_PASSWORD_PROMPT }' su -" do |ch, success|
        raise "Could not execute sudo su command" if ! success

        ch.on_data &method( :handle_sudo_password_prompt )

        ch.on_extended_data do |ch, type, data|
          $stderr.puts data
        end
      end
    end

    def handle_sudo_password_prompt( ch, data )
      $stdout.write data

      if data =~ Regexp.new( SUDO_PASSWORD_PROMPT )
        ch.send_data "#{ @sudo_password }\n"
        ch.on_data &method( :set_command_prompt )
      end
    end

    # Set the root command prompt to something we can
    # recognise, and wait until that prompt comes back
    def set_command_prompt( ch, data )
      $stdout.write data

      if data =~ ROOT_COMMAND_PROMPT_MATCH
        # Got it, now we can switch so sending commands
        ch[ :awaiting_prompt ] = false
        ch.on_data &method( :on_data )
        do_command ch, data
      elsif ! ch[ :awaiting_prompt ]
        # this is the first time through...
        ch[ :awaiting_prompt ] = true
        ch.send_data "export PS1='#{ ROOT_COMMAND_PROMPT }'"
      # else: Waiting for new root prompt
      end
    end

    def on_data( ch, data )
      $stdout.write data

      @prompts.each_pair do | prompt, send |
        if data =~ Regexp.new( prompt )
          ch.send_data "#{ send }\n"
          return
        end
      end

      if data =~ ROOT_COMMAND_PROMPT_MATCH
        do_command ch, data
      end
    end

    def do_command( ch, data )
      if ch[ :commands ].size > 0
        command = ch[ :commands ].shift
        if command.is_a?( Remote::Session::Send )
          send_file_chunk( ch, command )
        else
          ch.send_data "#{command}\n"
        end
      else
        ch.send_data "exit\n"
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

