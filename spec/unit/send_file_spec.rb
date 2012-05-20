# encoding: utf-8
load File.expand_path( '../spec_helper.rb', File.dirname(__FILE__) )

describe Remote::Session::SendFile do

  context '#initialize' do

    it 'should require two parameters' do
      expect do
        Remote::Session::SendFile.new( 'foo' )
      end.to raise_error( ArgumentError, 'wrong number of arguments (1 for 2)' )
    end

  end

  context 'attributes' do
    subject { Remote::Session::SendFile.new( 'foo', 'bar' ) }

    specify( 'local_path' )  { subject.local_path.should  == 'foo' }
    specify( 'remote_path' ) { subject.remote_path.should == 'bar' }
    specify( 'chunk_size' )  { subject.chunk_size.should  == 1024  }
  end

  context 'instance_methods' do
    subject { Remote::Session::SendFile.new( '/local/path', '/remote/path' ) }

    context '#eof?' do
      specify { subject.eof?.should be_true }

      it 'should delegate to the file' do
        @file = stub( 'file' )
        File.stub!( :open ).with( '/local/path', 'r' ).and_return( @file )
        @file.should_receive( :eof? ).and_return( false )

        subject.open

        subject.eof?.should be_false
      end
    end

    context '#open' do
      it 'should rewind the file, if already open' do
        @file = stub( 'file', :eof? => false )
        File.should_receive( :open ).with( '/local/path', 'r' ).and_return( @file )
        @file.should_receive( :rewind )

        subject.open

        subject.open
      end
    end

    context '#close' do

      before :each do
        @file = stub( 'file' )
      end

      it 'should close the file' do
        File.stub!( :open ).with( '/local/path', 'r' ).and_return( @file )

        subject.open

        @file.should_receive( :close )

        subject.close
      end

      it 'should do nothing is the file is not open' do
        File.should_not_receive( :open )
        @file.should_not_receive( :close )

        subject.close
      end

    end

    context '#read' do

      before :each do
        @file = stub( 'file' )
        File.stub!( :open ).with( '/local/path', 'r' ).and_return( @file )
      end

      it 'should open the file' do
        @file.stub!( :read ).and_return( 'aaa' )

        File.should_receive( :open ).with( '/local/path', 'r' ).and_return( @file )

        subject.read
      end

      it 'should fail, if the local file does non exist' do
        File.stub!( :open ).and_raise( 'Stubbed error' )

        expect do
          subject.read
        end.to raise_error
      end

      it 'should read chunks' do
        @file.should_receive( :read ).and_return( 'stuff' )

        subject.read.should == 'stuff'
      end

      it 'should read chunk_size bytes at a time' do
        @file.should_receive( :read ).with( 1024 ).and_return( 'x' * 1024 )

        subject.read.should == 'x' * 1024
      end

    end

  end

end

