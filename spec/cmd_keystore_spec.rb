# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'json'
require 'cmd_common'

RSpec.describe 'murano keystore', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('keystoreTest')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'set', 'bob', 'built'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'gets' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'get', 'bob'))
    expect(out.chomp).to eq('built')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'lists' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'list'))
    expect(out.chomp).to eq('bob')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'infos' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'info', '-c', 'outformat=json'))
    expect { out = JSON.parse(out) }.to_not raise_error
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
    expect(out).to match(
      'quota' => { 'keys' => a_kind_of(Integer) },
      'usage' => { 'keys' => 1, 'size' => a_kind_of(Integer) },
    )
  end

  it 'deletes' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'delete', 'bob'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'list'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'clearAll' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'set', 'another', 'value'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'clearAll'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'list'))
    expect(out.chomp).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'can call other commands' do
    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'command', 'lpush', 'another', 'value'))
    expect(out.chomp).to eq('1')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'keystore', 'command', 'rpop', 'another'))
    expect(out.chomp).to eq('value')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
end

