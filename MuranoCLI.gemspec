# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require_relative 'lib/MrMurano/version.rb'

Gem::Specification.new do |s|
  s.name        = 'MuranoCLI'
  s.version     = MrMurano::VERSION
  s.authors     = ['Michael Conrad Tadpol Tilstra']
  s.email       = ['miketilstra@exosite.com']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/exosite/MuranoCLI'
  s.summary     = 'Do more from the command line with Murano'
  s.description = %(
Do more from the command line with Murano.

Push and pull data from Murano.
Get status on what things have changed.
See a diff of the changes before you push.

And so much more.

(This gem was formerly known as MrMurano.)
  ).strip
  s.required_ruby_version = '~> 2.0'

  # If you want to print a message on Gem install, use the P.I.M., e.g.,:
  #   s.post_install_message = %(...)

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency('certified', '1.0.0')
  s.add_runtime_dependency('commander', '~> 4.4.3')
  s.add_runtime_dependency('dotenv', '~> 2.1.1')
  # 2017-08-15: Getting warning when running --user-install gem in 2.4.0. [lb]:
  #   Ignoring eventmachine-1.2.3 because its extensions are not built.
  #     Try: gem pristine eventmachine --version 1.2.3
  #   This might be because 'json' was also being complained about.
  s.add_runtime_dependency('eventmachine', '~> 1.2.5')
  s.add_runtime_dependency('faye-websocket', '~> 0.10.7')
  s.add_runtime_dependency('highline', '~> 1.7.8')
  s.add_runtime_dependency('http-form_data', '~> 1.0.3')
  s.add_runtime_dependency('inflecto')
  s.add_runtime_dependency('inifile', '~> 3.0')
  s.add_runtime_dependency('json', '~> 2.1.0')
  s.add_runtime_dependency('json-schema', '~> 2.7.0')
  s.add_runtime_dependency('mime-types', '~> 3.1')
  s.add_runtime_dependency('mime-types-data', '~> 3.2016.0521')
  #s.add_runtime_dependency('orderedhash', '~> 0.0.6')
  s.add_runtime_dependency('os', '~> 1.0.0')
  s.add_runtime_dependency('paint', '~> 2.0.0')
  # 2017-08-04: public_suffix 3.0.0 is for Ruby >= 2.1.
  #   It's included by json, so make sure it's the old one.
  s.add_runtime_dependency('public_suffix', '~> 2.0.5')
  s.add_runtime_dependency('rainbow', '~> 2.2.2')
  s.add_runtime_dependency('terminal-table', '~> 1.8.0')
  s.add_runtime_dependency('vine', '~> 0.4')
  s.add_runtime_dependency('whirly', '~> 0.2.4')
  # LATER/2017-09-12: See MRMUR-160 and MRMUR-161:
  #   Windows build fails unless `rake` is packaged.
  s.add_runtime_dependency('rake', '~> 12.1.0')

  # `bundle install --with=test`
  s.add_development_dependency('bundler', '~> 1.7.6')
  s.add_development_dependency('byebug', '~> 9.0.6')
  #s.add_development_dependency('coderay', '~> ???')
  #s.add_development_dependency('rake', '~> 12.1.0')
  s.add_development_dependency('rspec', '~> 3.5')
  s.add_development_dependency('rubocop', '~> 0.49.1')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('webmock', '~> 2.3.0')
  s.add_development_dependency('websocket-driver', '~> 0.7.0')
  # maybe? s.add_development_dependency('vcr', '~> ???')
  s.add_development_dependency('yard')

  # `bundle install --with=windows`
  # FIXME/2017-09-12: Pin to 1.3.8 until x86 issue is resolved:
  #   https://github.com/larsch/ocra/issues/124
  s.add_development_dependency('ocra', '1.3.8')
end

