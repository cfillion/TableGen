# Table Generator

Plain text table generator for ruby.

## Installation

Add this line to your application's Gemfile:

    gem 'tablegen'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install tablegen

## Documentation

The documentation is hosted at
[http://rubydoc.info/gems/tablegen/TableGen](http://rubydoc.info/gems/tablegen/TableGen).

## Basic Usage

    require 'tablegen'

    table = TableGen.new
    table.header 'Browser Name', 'Layout Engine', 'License'
    table.separator
    table.row 'Chromium', 'Blink', 'BSD'
    table.row 'dwb', 'WebKit', 'GNU GPLv3'
    table.row 'Internet Explorer', 'Trident', 'Proprietary'
    table.row 'Mozilla Firefox', 'Gecko', 'MPL'
    puts table

Output:

    Browser Name      Layout Engine License
    ===========================================
    Chromium          Blink         BSD
    dwb               WebKit        GNU GPLv3
    Internet Explorer Trident       Proprietary
    Mozilla Firefox   Gecko         MPL

## Contributing

1. [Fork it](https://bitbucket.org/cfi30/tablegen/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Test your changes (`rake`)
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
