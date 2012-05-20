# encoding: utf-8
load File.expand_path( '../spec_helper.rb', File.dirname(__FILE__) )

describe Remote::Session::Send do

  context '#initialize' do

    it 'should require one parameter'do
      expect do
        Remote::Session::Send.new( 'foo', 'bar' )
      end.to raise_error( ArgumentError, 'wrong number of arguments (2 for 1)' )
    end

  end

  context 'attributes' do
    subject { Remote::Session::Send.new( 'foo' ) }

    specify( 'remote_path' ) { subject.remote_path.should == 'foo' }
    specify( 'chunk_size' )  { subject.chunk_size.should  == 1024 }
  end

  context 'instance_methods' do
    subject { Remote::Session::Send.new( '/remote/path' ) }

    context '#open?' do
      specify { subject.open?.should be_false }
    end

  end

end

