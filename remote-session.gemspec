# -*- encoding: utf-8 -*-
$:.unshift( File.join( File.dirname( __FILE__ ), 'lib' ) )
require 'remote/session/version'

Gem::Specification.new do |gem|
  gem.authors       = ['Joe Yates']
  gem.email         = ['joe.g.yates@gmail.com']
  gem.description   = %q{This gem uses Net::SSH to create a connection and allow command execution over it.
Run commands as the logged on user, or via sudo as any permitetd user (defaults to root).}
  gem.summary       = %q{Run user commands, and sudo, commands over an SSH connection}
  gem.homepage      = ''

  gem.files         = `git ls-files`.split($\)
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = 'remote-session'
  gem.require_paths = ['lib']
  gem.version       = Remote::Session::VERSION

  gem.add_runtime_dependency 'rake', '>= 0.8.7'
  gem.add_runtime_dependency 'net-ssh'

  gem.add_development_dependency 'rspec',  '>= 2.3.0'
  if RUBY_VERSION < '1.9'
    gem.add_development_dependency 'rcov'
  else
    gem.add_development_dependency 'simplecov'
  end

  gem.rubyforge_project = 'nowarning'
end

