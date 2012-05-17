# -*- encoding: utf-8 -*-
require File.expand_path('../lib/remote/session/version', __FILE__)

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

  gem.rubyforge_project = 'nowarning'
end

