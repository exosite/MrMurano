# Last Modified: 2017.09.25 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano syncdown', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('syncdownTestPrd')
    out, err, status = Open3.capture3(
      capcmd('murano', 'product', 'create', @product_name, '--save')
    )
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('syncdownTestApp')
    out, err, status = Open3.capture3(
      capcmd('murano', 'application', 'create', @applctn_name, '--save')
    )
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@product_name}")
    olines = out.lines
    expect(strip_fancy(olines[0])).to eq(
      "Linked '#{@product_name}' to '#{@applctn_name}'\n"
    )
    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  after(:example) do
    # VERIFY/2017-07-03: Skipping assign unset. Murano will clean up, right?

    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', '-y', @applctn_name)
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', '--yes', @product_name)
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context 'without ProjectFile' do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      #FileUtils.mkpath('specs')
      #FileUtils.copy(
      #  File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
      #  'specs/resources.yaml'
      #)
      # 2017-07-03: So long as this command does not syncdown first, these
      # two files -- that conflict in name with what's on the platform --
      # won't be a problem (but would be if we synceddown first).
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_conflict/.'), '.')
    end

    it 'syncdown' do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      #expect(out).to eq('')
      #out_lines = out.lines
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(
        [
          "Adding item table_util\n",
          "Updating item timer_timer\n",
          # E.g., "Updating item i4kl64nn86xk00000_event\n":
          a_string_starting_with('Updating item '),
          "Updating item tsdb_exportJob\n",
          "Updating item user_account\n",
          # FIXME/2017-08-09: This test includes a fixture with "device2 data_in",
          # which is deprecated, AFAIK [lb]. We convert it to "device2.event",
          # but I think what we really want is to edit "<solution_id>.event".
          "Adding item device2_event\n",
          "Adding item POST_/api/fire\n",
          "Adding item PUT_/api/fire/{code}\n",
          "Adding item DELETE_/api/fire/{code}\n",
          "Adding item GET_/api/onfire\n",
          "Adding item /icon.png\n",
          "Adding item /\n",
          "Adding item /js/script.js\n",
        ]
      )

      #expect(err).to eq('')
      expect(strip_fancy(err)).to start_with("\e[33mSkipping missing location '")
      expect(status.exitstatus).to eq(0)

      FileUtils.rm_r(%w[files modules routes services])
      expect(Dir['**/*']).to eq([])

      out, err, status = Open3.capture3(capcmd('murano', 'syncdown'))
      #expect(out).to eq('')
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
      # Look for skipping missing location lines, e.g.,
      #   "\e[33mSkipping missing location /tmp/d20170623-20035-17496y/project/modules\e[0m\n"
      # 2017-07-03: Did I [lb] change syncdown not to complain about missing locations?
      #expect(err.lines).to include(
      #  a_string_ending_with("routes\e[0m\n"),
      #  a_string_ending_with("files\e[0m\n"),
      #  a_string_ending_with("modules\e[0m\n"),
      #  a_string_ending_with("services\e[0m\n"),
      #)
      #expect(err).to eq('')
      expect(strip_fancy(err)).to start_with("\e[33mSkipping missing location '")
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
        # 2017-07-03: services/ would not exist if we did not include
        #   fixtures/syncable_conflict/.
        'services',
        # 2017-07-13: No longer syncing device2_event; is internal to platform.
        #'services/device2_event.lua',
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
        ]
      )
      expect(status.exitstatus).to eq(0)
    end
  end

  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

