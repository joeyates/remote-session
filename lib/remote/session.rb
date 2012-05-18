require 'remote/session/version'
require 'net/sftp'
require 'net/ssh'

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

    def sudo( command )
      raise "Session is closed" if @session.nil?

      puts "@#{ @host }: sudo #{ command }"
      @session.open_channel do |ch|
        ch.request_pty do |ch, success|
          raise "Could not obtain pty" if ! success

          channel_exec ch, command
        end
      end
      @session.loop
    end

    def close
      @session.close
      @session = nil
    end

    def sudo_put( remote_path, &block )
      temp_path = "/tmp/remote-session.#{ Time.now.to_f }"
      run "mkdir #{ temp_path }"
      run "chmod 0700 #{ temp_path }"

      temp_file = File.join( temp_path, File.basename( remote_path ) )
      put temp_file, &block

      sudo "cp -f #{ temp_file } #{ remote_path }"
      run "rm -rf #{ temp_path }"
    end
    
    def put( remote_path, &block )
      sftp = Net::SFTP::Session.new( @session ).connect!
      sftp.file.open( remote_path, 'w' ) do |f|
        f.puts block.call
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

    def channel_exec( ch, command )
      ch.exec "sudo -p '#{ SUDO_PROMPT }' #{ command }" do |ch, success|
        raise "Could not execute sudo command: #{ command }" if ! success

        ch.on_data do | ch, data |
          if data =~ Regexp.new( SUDO_PROMPT )
            ch.send_data "#{ @sudo_password }\n"
          else
            prompt_matched = false
            @prompts.each_pair do | prompt, send |
              if data =~ Regexp.new( prompt )
                ch.send_data "#{ send }\n"
                prompt_matched = true
              end
            end
            puts data if ! prompt_matched
          end
        end

        ch.on_extended_data do |ch, type, data|
          raise "Error #{ data } while performing command: #{ command }"
        end
      end
    end

  end
end

