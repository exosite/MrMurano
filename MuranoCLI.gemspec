# Last Modified: 2017.07.25 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

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
  s.description = %(Do more from the command line with Murano

  Push and pull data from Murano.
  Get status on what things have changed.
  See a diff of the changes before you push.

  and so much more.

  This gem was formerly known as MrMurano.
)
  s.required_ruby_version = '~> 2.0'

  # FIXME: 2017-05-25: Remove this message eventually.
  s.post_install_message = %(
MuranoCLI v3.0 introduces backwards-incompatible changes.

If your business was created with MuranoCLI v2.x, you will
want to continue using the old gem, which you can run by
explicitly specifying the version. For instance,

  murano _2.2.4_ --version

)

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = ['lib']

  s.add_runtime_dependency('certified', '1.0.0')
  s.add_runtime_dependency('commander', '~> 4.4.3')
  s.add_runtime_dependency('dotenv', '~> 2.1.1')
  s.add_runtime_dependency('highline', '~> 1.7.8')
  s.add_runtime_dependency('http-form_data', '~> 1.0.1')
  s.add_runtime_dependency('inflecto')
  s.add_runtime_dependency('inifile', '~> 3.0')
  s.add_runtime_dependency('json-schema', '~> 2.7.0')
  s.add_runtime_dependency('mime-types', '~> 3.1')
  s.add_runtime_dependency('mime-types-data', '~> 3.2016.0521')
  s.add_runtime_dependency('orderedhash', '~> 0.0.6')
  s.add_runtime_dependency('paint', '~> 2.0.0')
  s.add_runtime_dependency('rainbow', '~> 2.2.2')
  s.add_runtime_dependency('terminal-table', '~> 1.7.3')
  s.add_runtime_dependency('vine', '~> 0.4')
  s.add_runtime_dependency('whirly', '~> 0.2.4')

  s.add_development_dependency('bundler', '~> 1.7.6')
  s.add_development_dependency('ocra', '~> 1.3.8')
  s.add_development_dependency('rake', '~> 10.1.1')
  s.add_development_dependency('rspec', '~> 3.5')
  s.add_development_dependency('simplecov')
  s.add_development_dependency('webmock', '~> 2.1.0')
  # maybe? s.add_development_dependency('vcr', '~> ???')
end

