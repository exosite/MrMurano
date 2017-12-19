# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

source 'http://rubygems.org'

#gemspec

gem 'certified', '1.0.0'
gem 'commander', '~> 4.4.3'
gem 'dotenv', '~> 2.1.1'
gem 'eventmachine', '~> 1.2.5'
gem 'faye-websocket', '~> 0.10.7'
gem 'highline', '~> 1.7.8'
gem 'http-form_data', '~> 1.0.3'
gem 'inflecto'
gem 'inifile', '~> 3.0'
gem 'json', '~> 2.1.0'
gem 'json-schema', '~> 2.7.0'
gem 'mime-types', '~> 3.1'
gem 'mime-types-data', '~> 3.2016.0521'
#gem 'orderedhash', '~> 0.0.6'
gem 'os', '~> 1.0.0'
gem 'paint', '~> 2.0.0'
# 2017-08-04: public_suffix 3.0.0 is for Ruby >= 2.1.
#   It's included by json, so make sure it's the old one.
gem 'public_suffix', '~> 2.0.5'
gem 'rainbow', '~> 2.2.2'
# LATER/2017-09-12: See MRMUR-160 and MRMUR-161:
#   Windows build fails unless `rake` is packaged.
gem 'rake', '~> 12.1.0'
gem 'terminal-table', '~> 1.8.0'
gem 'vine', '~> 0.4'
gem 'whirly', '~> 0.2.4'

group :test do
  #gem 'bundler', '~> 1.7.6'
  gem 'byebug', '~> 9.0.6'
  gem 'coderay', require: false
  #gem 'rake', '~> 10.1.1'
  gem 'rspec', '~> 3.5'
  gem 'rubocop', '~> 0.49.1'
  gem 'simplecov', require: false
  gem 'webmock', '~> 2.3.0'
  gem 'websocket-driver', '~> 0.7.0'
  #gem 'vcr'
  gem 'yard'
end

group :windows do
  # FIXME/2017-09-12: Pin to 1.3.8 until x86 issue is resolved:
  #   https://github.com/larsch/ocra/issues/124
  gem 'ocra', '1.3.8'
end

