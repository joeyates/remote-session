require 'rspec'

if RUBY_VERSION < '1.9'
  require 'rspec/autorun'
end
  require 'simplecov'
  if defined?( GATHER_RSPEC_COVERAGE )
    SimpleCov.start do
      add_filter "/spec/"
    end
  end
end

require File.expand_path( File.dirname(__FILE__) + '/../lib/remote/session' )

