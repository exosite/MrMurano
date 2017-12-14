# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'json'
require 'cmd_common'

RSpec.describe 'murano cors', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('corstest')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'show CORS' do
    out, err, status = Open3.capture3(capcmd('murano', 'cors', '-c', 'outformat=json'))
    expect { JSON.parse(out) }.to_not raise_error
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'sets CORS' do
    File.open('cors.yaml', 'wb') do |io|
      io << { origin: ['http://localhost:*'] }.to_json
    end

    out, err, status = Open3.capture3(capcmd('murano', 'cors', 'set', 'cors.yaml'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'cors', '-c', 'outformat=json'))
    expect { out = JSON.parse(out) }.to_not raise_error
    expect(out).to include('origin' => contain_exactly('http://localhost:*'))
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
end

#  vim: set ai et sw=2 ts=2 :
