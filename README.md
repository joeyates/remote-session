remote-session [![Build Status](https://secure.travis-ci.org/joeyates/remote-session.png)][Continuous Integration]
==============

*Run user, and sudo, commands over an SSH connection*

  * [Source Code]
  * [API documentation]
  * [Rubygem]
  * [Continuous Integration]

[Source Code]: https://github.com/joeyates/remote-session "Source code at GitHub"
[API documentation]: http://rubydoc.info/gems/remote-session/frames "RDoc API Documentation at Rubydoc.info"
[Rubygem]: http://rubygems.org/gems/remote-session "Ruby gem at rubygems.org"
[Continuous Integration]: http://travis-ci.org/joeyates/remote-session "Build status by Travis-CI"

## Installation

Add this line to your application's Gemfile:

    gem 'remote-session'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install remote-session

## Usage

```ruby
require 'remote-session'

r = Remote::Session.new( 'host.example.com' )
puts r.run( 'pwd' )
puts r.sudo( 'apt-get update' )
r.close
```

In a block:
```ruby
Remote::Session.new( 'host.example.com', :user => 'user' ) | r | do
  puts r.run( 'pwd' )
  puts r.sudo( 'apt-get update' )
end
```

Options:
```ruby
Remote::Session.new( 'host.example.com', :user => 'user', :password => 'password' ) | r | do
  puts r.run( 'pwd' )
  puts r.sudo( 'apt-get update' )
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

