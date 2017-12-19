# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'cmd_common'

RSpec.describe 'murano business', :cmd, :needs_password do
  include_context 'CI_CMD'

  context 'without project' do
    it 'help' do
      cmd_verify_help('business')
    end
  end

  context 'list' do
    it 'as table' do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to match(/^(\+-+){3}\+$/)
      expect(olines[1]).to match(/^\| bizid\s+\| role\s+\| name\s+\|$/)
      expect(olines[2]).to match(/^(\+-+){3}\+$/)
      expect(olines[-1]).to match(/^(\+-+){3}\+$/)
      expect(status.exitstatus).to eq(0)
    end

    it 'as json' do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '-c', 'outformat=json'))
      expect(err).to eq('')
      expect { JSON.parse(out) }.to_not raise_error
      expect(status.exitstatus).to eq(0)
    end

    it 'only ids' do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '--idonly'))
      expect(err).to eq('')
      expect(out).to match(/^(\S+\s)*\S+$/)
      expect(status.exitstatus).to eq(0)
    end

    it 'output to file' do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '--idonly', '-o', 'bob'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)
      expect(File.exist?('bob')).to be true
      data = IO.read('bob')
      expect(data).to match(/^(\S+\s)*\S+$/)
    end

    it 'fewer fields' do
      out, err, status = Open3.capture3(capcmd('murano', 'business', 'list', '--brief'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to match(/^(\+-+)+\+$/)
      expect(olines[1]).to match(/^(\| \S+\s+)+\|$/)
      expect(olines[2]).to match(/^(\+-+)+\+$/)
      expect(olines[-1]).to match(/^(\+-+)+\+$/)
      expect(status.exitstatus).to eq(0)
    end
  end
end

