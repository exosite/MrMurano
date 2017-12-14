# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'yaml'
require 'cmd_common'

RSpec.describe 'murano content', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('contestTest')
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', '--yes', @product_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'life cycle' do
    out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
    #expect(out.lines).to match(
    #  [
    #    a_string_matching(/^(\+-+){2}\+$/),
    #    a_string_matching(/^\| Name\s+\| Size\s+\|$/),
    #    a_string_matching(/^(\+-+){2}\+$/),
    #    a_string_matching(/^(\+-+){2}\+$/),
    #  ]
    #)
    #expect(err).to eq('')
    expect(out.lines).to match([])
    expect(err).to eq("\e[33mDid not find any content\e[0m\n")
    expect(status.exitstatus).to eq(0)

    FileUtils.copy(File.join(@testdir, 'spec/fixtures/dumped_config'), 'myFile')
    out, err, status = Open3.capture3(capcmd('murano', 'content', 'upload', 'myFile', '--tags', 'random=junk'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
    expect(err).to eq('')
    expect(out.lines).to match(
      [
        a_string_matching(/^(\+-+){2}\+$/),
        a_string_matching(/^\| Name\s+\| Size\s+\|$/),
        a_string_matching(/^(\+-+){2}\+$/),
        a_string_matching(/^\| myFile\s+\| \d+\s+\|$/),
        a_string_matching(/^(\+-+){2}\+$/),
      ]
    )
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'content', 'info', 'myFile'))
    expect(err).to eq('')
    expect { out = YAML.load(out) }.to_not raise_error
    expect(out).to match(
      'type' => a_kind_of(String),
      'length' => a_kind_of(Integer),
      'last_modified' => a_kind_of(String),
      'id' => 'myFile',
      'tags' => {
        'random' => 'junk',
      }
    )
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'content', 'download', 'myFile', '-o', 'testDown'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
    expect(File.exist?('testDown')).to be true
    dcf = IO.read('myFile')
    tdf = IO.read('testDown')
    expect(tdf).to eq(dcf)

    out, err, status = Open3.capture3(capcmd('murano', 'content', 'delete', 'myFile', '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'content', 'list'))
    #expect(out.lines).to match(
    #  [
    #    a_string_matching(/^(\+-+){2}\+$/),
    #    a_string_matching(/^\| Name\s+\| Size\s+\|$/),
    #    a_string_matching(/^(\+-+){2}\+$/),
    #    a_string_matching(/^(\+-+){2}\+$/),
    #  ]
    #)
    #expect(err).to eq('')
    expect(out.lines).to match([])
    expect(err).to eq("\e[33mDid not find any content\e[0m\n")
    expect(status.exitstatus).to eq(0)
  end
end

#  vim: set ai et sw=2 ts=2 :
