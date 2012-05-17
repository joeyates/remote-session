require 'remote/session/version'
require 'net/ssh'

module Remote
  class Session
    SUDO_PROMPT = 'sudo_prompt'

    def self.open( host, options = {}, &block )
      rs = new( host, options )

      block.call rs

      rs.close
    end

    attr_accessor :host, :user, :password, :options

    def initialize( host, options = {} )
      @host     = host
      @options  = options.clone
      @user     = @options.delete( :user ) || ENV[ 'USER' ]
      @password = @options.delete( :password )
      connect
    end

    def run( command )
      raise "Session is closed" if @session.nil?
      puts "@#{ @host }: #{ command }"
      puts @session.exec!( command )
    end

    def sudo( command, prompts = {} )
      raise "Session is closed" if @session.nil?

      puts "@#{ @host }: sudo #{ command }"
      @session.open_channel do |ch|
        ch.request_pty do |ch, success|
          raise "Could not obtain pty" if ! success

          channel_exec ch, command, prompts
        end
      end
      @session.loop
    end

    def close
      @session.close
      @session = nil
    end

    private

    def ssh_options
      s = {}
      s[ :password ] = @password if @password
      s
    end

    def connect
      @session = Net::SSH.start( @host, @user, ssh_options )
    end

    def channel_exec( ch, command, prompts )
      ch.exec "sudo -p '#{ SUDO_PROMPT }' #{ command }" do |ch, success|
        raise "Could not execute sudo command: #{ command }" if ! success

        ch.on_data do | ch, data |
          if data =~ Regexp.new( SUDO_PROMPT )
            ch.send_data "#{ @options[ :sudo_password ] }\n"
          else
            prompt_matched = false
            prompts.each_pair do | prompt, send |
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

