# encoding: utf-8
load File.expand_path( '../spec_helper.rb', File.dirname(__FILE__) )

module SpecOutputCapture

  def expect_output
    stdout = []
    @rs.stub!( :puts ) do | s |
      stdout << s + "\n"
    end
    $stdout.stub!( :puts ) do | s |
      stdout << s + "\n"
    end
    $stdout.stub!( :write ) do | s |
      stdout << s
    end
    stderr = []
    $stderr.stub!( :puts ) do | s |
      stderr << s + "\n"
    end
    $stderr.stub!( :write ) do | s |
      stderr << s
    end

    yield

    $stdout.rspec_reset
    $stderr.rspec_reset

    { :stdout => stdout, :stderr => stderr }
  end

end

describe Remote::Session do

  include SpecOutputCapture

  TEST_HOST = 'host.example.com'

  context 'initialization' do

    before :each do
      Net::SSH.stub!( :start )
      @username         = ENV[ 'USER' ]
      ENV[ 'USER' ] = 'the_user'
    end

    after :each do
      ENV[ 'USER' ] = @username
    end

    it 'should require a hostname parameter' do
      expect do
        Remote::Session.new
      end.       to         raise_error( ArgumentError, 'wrong number of arguments (0 for 1)' )
    end

    it 'should connect automatically' do
      Net::SSH.should_receive( :start )

      Remote::Session.new( TEST_HOST )
    end

    it 'username should default to the current user' do
      Net::SSH.should_receive( :start ).with( TEST_HOST, 'the_user', {} )

      Remote::Session.new( TEST_HOST )
    end

    it 'should accept username option' do
      Net::SSH.should_receive( :start ).with( TEST_HOST, 'another_user', {} )

      Remote::Session.new( TEST_HOST, :username => 'another_user' )
    end

    it 'should use any supplied password' do
      Net::SSH.should_receive( :start ).with( TEST_HOST, 'another_user', { :password => 'secret' } )

      Remote::Session.new( TEST_HOST, :username => 'another_user', :password => 'secret' )
    end

  end

  context 'instance methods' do

    before :each do
      @ssh = stub( 'Net::SSH instance' )
      Net::SSH.stub!( :start => @ssh )
    end

    context '#open' do

      it 'should run the block' do
        @ssh.stub!( :close )

        called = false
        Remote::Session.open( TEST_HOST, :username => 'another_user' ) do | rs |
          called = true
        end

        called.should be_true
      end

      it 'should open a connection' do
        @ssh.stub!( :close )

        Net::SSH.should_receive( :start ).with( 'host.example.com', 'another_user', {} )

        Remote::Session.open( TEST_HOST, :username => 'another_user' ) {}
      end

      it 'should require a block' do
        expect do
          Remote::Session.open( TEST_HOST, :username => 'another_user' )
        end.       to         raise_error( NoMethodError, "undefined method `call' for nil:NilClass" )
      end

      it 'should close the connection' do
        @ssh.should_receive( :close )

        Remote::Session.open( TEST_HOST, :username => 'another_user' ) {}
      end

    end

    context '#run' do

      subject { Remote::Session.new( TEST_HOST ) }

      it 'should fail, if the session is closed' do
        @ssh.stub!( :close )
        subject.close

        expect do
          subject.run( 'pwd' )
        end.to raise_error( RuntimeError, 'Session is closed' )
      end

      it 'should print the command to stdout' do
        @ssh.stub!( :exec! => "/foo/bar\n" )

        subject.should_receive( :puts ).with( "@#{TEST_HOST}: pwd" )
        subject.should_receive( :puts ).with( "/foo/bar\n" )

        subject.run( 'pwd' )
      end

      it 'should run the command' do
        subject.stub!( :puts )

        @ssh.should_receive( :exec! ).with( 'pwd' ).and_return( "/foo/bar\n" )

        subject.run( 'pwd' )
      end

    end

    context '#sudo' do

      before :each do
        @ch = stub( 'channel' )
        @commands = {}
        @ch.stub!( :[]= ) do | k, v |
          @commands[ k ] = v
        end
        @ch.stub!( :[] ) do | k |
          @commands[ k ]
        end
      end

      subject { Remote::Session.new( TEST_HOST ) }

      it 'should fail, if the session is closed' do
        @ssh.stub!( :close )
        subject.close

        expect do
          subject.sudo( 'pwd' )
        end.to raise_error( RuntimeError, 'Session is closed' )
      end

      it 'should run the su command' do
        subject.stub!( :puts )

        @ssh.should_receive( :open_channel ) do |&open_channel_block|
          @ch.should_receive( :request_pty ) do |&request_pty_block|
            request_pty_block.call( @ch, true )
          end

          @ch.should_receive( :exec ).with( "sudo -k -p 'remote-session-sudo-prompt' su -" )

          open_channel_block.call @ch
        end
        @ssh.should_receive( :loop )

        subject.sudo( 'pwd' )
      end

      context 'in channel' do

        before :each do
          @rs = Remote::Session.new( TEST_HOST, { :sudo_password => 'secret' } )
          @rs.stub!( :puts )

          @ssh.stub!( :loop => nil )
          @ssh.stub!( :open_channel ) do |&block|
            block.call @ch
          end
        end

        it 'should fail if pty request is unsuccessful' do
          @ch.stub!( :request_pty ) do |&block|
            expect do
              block.call( @ch, false )
            end.to raise_error( RuntimeError, 'Could not obtain pty' )
          end

          @rs.sudo( 'pwd' )
        end

        context 'with pty' do

          before :each do
            @ch.stub!( :request_pty ) do |&block|
              block.call( @ch, true )
            end
          end

          it 'should fail if the sudo command fails' do
            @ch.stub!( :exec ) do |&block|
              expect do
                block.call( @ch, false )
              end.to raise_error( RuntimeError, 'Could not execute sudo su command' )
            end

            @rs.sudo( 'pwd' )
          end

          context 'in exec' do

            before :each do
              @ch.stub!( :exec ) do |&block|
                block.call( @ch, true )
              end
              @ch.stub!( :send_data => nil )
              @ch.stub!( :on_extended_data => nil )
              $stdout.stub( :write => nil )

              # For each call to Channel.on_data, @data contains the strings
              # to send back to the block
              @data = [ [ 'remote-session-sudo-prompt' ],               # channel_exec call
                         [ 'any prompt#', 'remote-session-prompt#' ],    # handle_sudo_password_prompt call
                         [ 'remote-session-prompt#', 'remote-session-prompt#', 'remote-session-prompt#' ] ]
              @ch.stub!( :on_data ) do |&block|
                @data.shift.each { |response| block.call @ch, response }
              end
            end

            it 'should supply the sudo password, when prompted' do
              @ch.should_receive( :send_data ).with( "secret\n" )

              @rs.sudo( 'pwd' )
            end

            it 'should echo the sudo prompt' do
              output = expect_output do
                @rs.sudo( 'pwd' )
              end
 
              output[ :stdout ][ 0 ].should == 'remote-session-sudo-prompt'
            end

            context 'after sudo prompt' do

              it 'should set the root command prompt' do
                @ch.should_receive( :send_data ).with( "export PS1='remote-session-prompt#'\n" )

                @rs.sudo( 'pwd' )
              end

              it 'should echo until the prompt is set' do
                @data[ 1 ] = [ 'prompt#', 'stuff1', 'stuff2', 'remote-session-prompt#' ]

                output = expect_output do
                  @rs.sudo( 'pwd' )
                end

                output[ :stdout ].should include 'stuff1'
                output[ :stdout ].should include 'stuff2'
              end

              context 'with special command prompt' do

                it 'should send the command' do
                  @ch.should_receive( :send_data ).with( "pwd\n" )

                  subject.sudo( 'pwd' )
                end

                it 'should run multiple commands' do
                  sent = []
                  @ch.stub!( :send_data ) { | s | sent << s }

                  subject.sudo( [ 'pwd', 'cd /etc', 'ls' ] )

                  sent[-4..-1].should == [ "pwd\n", "cd /etc\n", "ls\n", "exit\n" ]
                end

                it 'should output returning data' do
                  @data[ 2 ] = [ 'remote-session-prompt#', 'some_data', 'remote-session-prompt#' ]
                  output = expect_output do
                    @rs.sudo( 'pwd' )
                  end

                  output[ :stdout ].should include 'some_data'
                end

                context 'sending files' do

                  before :each do
                    @sf = stub( 'Remote::Session::SendFile instance', :open => nil, :close => nil )
                  end

                  it 'should copy files' do
                    @sf.should_receive( :is_a? ).with( Remote::Session::Send ).twice.and_return( true )
                    @sf.should_receive( :remote_path ).twice.and_return( '/remote/path' )

                    chunk = 0
                    open = false
                    @sf.should_receive( :open ) do
                      chunk = 1
                      open = true
                    end

                    @sf.stub!( :open? ) do
                      open
                    end

                    @sf.stub!( :eof? ) do
                      case chunk
                      when 0
                        true
                      when 1, 2
                        false
                      else
                        true
                      end
                    end

                    data = [ nil, 'first_chunk', 'second_chunk' ]
                    @sf.should_receive( :read ).twice do
                      d = data[ chunk ]
                      chunk += 1
                      d
                    end

                    sent = []
                    @ch.stub!( :send_data ) { | d | sent << d }

                    @rs.sudo( @sf )

                    sent.should include "echo -n 'Zmlyc3RfY2h1bms=\n' | base64 -d > /remote/path\n"
                    sent.should include "echo -n 'c2Vjb25kX2NodW5r\n' | base64 -d >> /remote/path\n"
                  end

                  it 'should copy empty files' do
                    @sf.stub!( :is_a? ).with( Remote::Session::Send ).and_return( true )
                    @sf.stub!( :open? => false )
                    @sf.stub!( :remote_path ).and_return( '/remote/path' )
                    @sf.stub!( :eof? => true )

                    sent = []
                    @ch.stub!( :send_data ) { | d | sent << d }


                    @rs.sudo( @sf )

                    sent.should include "echo -n '' | base64 -d > /remote/path\n"
                  end

                end

                context 'with user-supplied prompt' do
                  it 'should send the supplied data' do
                    @data[ 2 ] = [ 'remote-session-prompt#', 'Supply user password:', 'remote-session-prompt#' ]
                    @ch.should_receive( :send_data ).with( "this data\n" )
                    @rs.prompts[ 'user password:' ] = 'this data' 

                    @rs.sudo( 'pwd' )
                  end

                  it 'should echo the prompt' do
                    @data[ 2 ] = [ 'remote-session-prompt#', 'Supply user password:', 'remote-session-prompt#' ]
                    @rs.prompts[ 'user password:' ] = 'this data' 

                    output = expect_output do
                      @rs.sudo( 'pwd' )
                    end
 
                    output[ :stdout ].should include 'Supply user password:'
                  end

                end

                it 'should send error data to stdout' do
                  @ch.stub!( :on_data )

                  @ch.stub!( :on_extended_data ) do |&block|
                    block.call @ch, 'foo', 'It failed'
                  end

                  output = expect_output do
                    @rs.sudo( 'pwd' )
                  end

                  output[ :stderr ].should include "It failed\n"
                end

              end

            end

          end

        end

      end

    end

    context '#put' do

      before :each do
        @file2 = stub( 'file2' )
        @file1 = stub( 'file1', :open => lambda { |&block| block.call @file2 } )
        @sftp2 = stub( 'Net::SFTP::Session instance', :file => @file1,
                                                      :close_channel => nil )
        @sftp1 = stub( 'Net::SFTP::Session instance', :connect! => @sftp2 )
        Net::SFTP::Session.stub!( :new => @sftp1 )
      end

      subject { Remote::Session.new( TEST_HOST ) }

      it 'creates an SFTP session' do
        Net::SFTP::Session.should_receive( :new ).and_return( @sftp1 )
        @sftp1.should_receive( :connect! ).once.and_return( @sftp2 )

        subject.put( '/path' ) {}
      end

      it 'opens the file' do
        @file1.should_receive( :open ) do | *args, &block |
          args.should == ["/path", "w"]
        end

        subject.put( '/path' ) { 'content' }
      end

      it 'writes the data to the file' do
        @file1.stub!( :open ) do | *args, &block |
          block.call @file2
        end

        @file2.should_receive( :write ).with( 'content' )

        subject.put( '/path' ) { 'content' }
      end

    end

  end

end

