# Last Modified: 2017.09.28 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

# NOTE: This file is a copy of, and subset of, cmd_syncdown_both_spec.rb.

RSpec.describe 'murano single sync', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @applctn_name = rname('syncdownTestApp')
    out, err, status = Open3.capture3(
      capcmd('murano', 'application', 'create', @applctn_name, '--save')
    )
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end

  after(:example) do
    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', '-y', @applctn_name)
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context 'without ProjectFile' do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_conflict/.'), '.')
    end

    it 'syncdown' do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(
        [
          "Adding item table_util\n",
          a_string_starting_with('Updating item '),
          "Updating item user_account\n",
          "Adding item POST_/api/fire\n",
          "Adding item PUT_/api/fire/{code}\n",
          "Adding item DELETE_/api/fire/{code}\n",
          "Adding item GET_/api/onfire\n",
          "Adding item /icon.png\n",
          "Adding item /\n",
          "Adding item /js/script.js\n",
        ]
      )

      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      FileUtils.rm_r(%w[files modules routes services])
      expect(Dir['**/*']).to eq([])

      out, err, status = Open3.capture3(capcmd('murano', 'syncdown'))
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(
        [
          "Adding item table_util\n",
          # 2017-08-08: This says updating now because timer.timer is undeletable.
          #"Adding item timer_timer\n",
          "Updating item timer_timer\n",
          "Adding item POST_/api/fire\n",
          "Adding item DELETE_/api/fire/{code}\n",
          "Adding item PUT_/api/fire/{code}\n",
          "Adding item GET_/api/onfire\n",
          "Adding item /js/script.js\n",
          "Adding item /icon.png\n",
          "Adding item /\n",
        ]
      )
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      after = Dir['**/*'].sort
      expect(after).to include(
        'files',
        'files/icon.png',
        'files/index.html',
        'files/js',
        'files/js/script.js',
        'modules',
        'modules/table_util.lua',
        'routes',
        'routes/api-fire-{code}.delete.lua',
        'routes/api-fire-{code}.put.lua',
        'routes/api-fire.post.lua',
        'routes/api-onfire.get.lua',
        'services',
        'services/timer_timer.lua',
      )

      # A status should show no differences.
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      expect(out.lines).to match(
        [
          "Nothing new locally\n",
          "Nothing new remotely\n",
          "Nothing that differs\n",
          "Items without a solution:\n",
          " - R  Resource\n",
          " - I  Interface\n",
        ]
      )
      expect(status.exitstatus).to eq(0)
    end
  end
end

