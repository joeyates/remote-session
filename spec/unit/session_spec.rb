# encoding: utf-8
load File.expand_path( '../spec_helper.rb', File.dirname(__FILE__) )

module SpecOutputCapture

  def expect_output
    stdout = []
    @rs.stub!( :puts ) do | s |
      stdout << "{ s }\n"
    end
    $stdout.stub!( :write ) do | s |
      stdout << s
    end
    stderr = []
    $stderr.stub!( :write ) do | s |
      stderr << s
    end

    yield

    [ stdout, stderr ]
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
          @channel = stub( 'channel' )

          @channel.should_receive( :request_pty ) do |&request_pty_block|
            request_pty_block.call( @channel, true )
          end

          @channel.should_receive( :exec ).with( "sudo -p 'sudo_prompt' su -" )

          open_channel_block.call @channel
        end
        @ssh.should_receive( :loop )

        subject.sudo( 'pwd' )
      end

      context 'in channel' do

        before :each do
          @rs = Remote::Session.new( TEST_HOST, { :sudo_password => 'secret' } )
          @rs.stub!( :puts )

          @ssh.stub!( :loop => nil )
          @ch = stub( 'channel' )
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
              @ch.stub!( :on_extended_data => nil )
              @ch.stub!( :send_data )
              $stdout.stub!( :write => nil )
            end

            it 'should print the command to stdout' do
              @ch.stub!( :on_data ) do |&block|
                block.call( @ch, 'the_prompt' )
              end

              @ch.should_receive( :send_data ).with( "pwd\n" )

              subject.sudo( 'pwd' )
            end

            it 'should run multiple commands' do
              @ch.stub!( :on_data ) do |&block|
                block.call( @ch, 'the_prompt' )
                block.call( @ch, 'the_prompt' )
                block.call( @ch, 'the_prompt' )
                block.call( @ch, 'the_prompt' )
              end

              sent = []
              @ch.stub!( :send_data ) { | s | sent << s }

              subject.sudo( [ 'pwd', 'cd /etc', 'ls' ] )

              sent.should == [ "pwd\n", "cd /etc\n", "ls\n", "exit\n" ]
            end

            it 'should output returning data' do
              @ch.stub!( :on_data ) do |&block|
                block.call( @ch, 'some_data' )
              end

              expect_output do
                @rs.sudo( 'pwd' )
              end.should == [ [ 'some_data' ], [] ]
            end

            context 'with password prompt' do
              before :each do
                $stdout.stub( :write )
                @ch.stub!( :on_data ) do |&block|
                  block.call( @ch, 'sudo_prompt' )
                  block.call( @ch, 'root#' )
                end
              end

              it 'should supply the sudo password, when prompted' do
                @ch.should_receive( :send_data ).with( "secret\n" )

                @rs.sudo( 'pwd' )
              end

              it 'should not echo the standard prompt' do
                expect_output do
                  @rs.sudo( 'pwd' )
                end.should == [ [ 'root#' ], [] ]
              end
            end

            context 'with user-supplied prompt' do
              before :each do
                $stdout.stub( :write )
                @ch.stub!( :on_data ) do |&block|
                  block.call( @ch, 'Here is my prompt:' )
                  block.call( @ch, 'root#' )
                end
              end

              it 'should send the supplied data' do
                @ch.should_receive( :send_data ).with( "this data\n" )
                @rs.prompts[ 'my prompt' ] = 'this data' 

                @rs.sudo( 'pwd' )
              end

              it 'should not echo the prompt' do
                @rs.prompts[ 'my prompt' ] = 'this data' 

                expect_output do
                  @rs.sudo( 'pwd' )
                end.should == [ [ 'root#' ], [] ]
              end

            end

            it 'should send error data to stdout' do
              @ch.stub!( :on_data )

              @ch.stub!( :on_extended_data ) do |&block|
                block.call @ch, 'foo', 'It failed' 
              end

              expect_output do
                @rs.sudo( 'pwd' )
              end.should == [ [], [ "It failed", "\n" ] ]
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

      context '#sudo_put' do
        it 'should write to /tmp, then copy' do
          subject.stub!( :puts => nil )
          @ch = stub('channel' )
          @ch.stub!( :request_pty ) { |&block| block.call @ch, true }
          @ssh.stub!( :open_channel ) { |&block| block.call @ch }
          @ssh.stub!( :loop => nil )

          @ssh.should_receive( :exec! ).with( %r{^mkdir /tmp/remote-session.[\d\.]+$} )
          @ssh.should_receive( :exec! ).with( %r{^chmod 0700 /tmp/remote-session.[\d\.]+$} )
          @ch.should_receive( :exec ).with( %r{^sudo.*? su -$} )
          @ssh.should_receive( :exec! ).with( %r{rm -rf /tmp/remote-session.[\d\.]+$} )

          subject.sudo_put( '/path' ) { 'content' }
        end
      end

    end

  end

end

