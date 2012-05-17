# -*- encoding: utf-8 -*-
require File.expand_path('../lib/remote/session/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ['Joe Yates']
  gem.email         = ['joe.g.yates@gmail.com']
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
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

