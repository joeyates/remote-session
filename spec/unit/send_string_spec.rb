# encoding: utf-8
load File.expand_path( '../spec_helper.rb', File.dirname(__FILE__) )

describe Remote::Session::SendString do

  context 'attributes' do
    subject { Remote::Session::SendString.new( 'foo', 'bar' ) }

    specify( 'string' )      { subject.string.should      == 'foo' }
    specify( 'remote_path' ) { subject.remote_path.should == 'bar' }
    specify( 'chunk_size' )  { subject.chunk_size.should  == 1024  }
  end

  context 'instance_methods' do

    subject { Remote::Session::SendString.new( 'foo', 'remote/path' ) }

    context '#open' do

      it 'should instantiate a StringIO' do
        @stringio = stub( 'stringio' )
        StringIO.should_receive( :new ).with( 'foo' ).and_return( @stringio )

        subject.open
      end

    end

  end

end

