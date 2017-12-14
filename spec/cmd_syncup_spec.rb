# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'cmd_common'

RSpec.describe 'murano syncup', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('syncupTestPrd')
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('syncupTestApp')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@product_name}")
    olines = out.lines
    expect(strip_fancy(olines[0])).to eq("Linked '#{@product_name}' to '#{@applctn_name}'\n")
    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  context 'without ProjectFile' do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml',
      )
    end

    def verify_err_missing_location(err)
      elines = err.lines
      # E.g.,
      #   Skipping missing location ‘/tmp/d20170809-7670-z315jn/project/services’ (Services)
      #   Skipping missing location ‘/tmp/d20170809-7670-z315jn/project/services’ (Interfaces)
      expect(elines).to(satisfy { |_v| elines.length == 2 })
      elines.each do |line|
        expect(strip_fancy(line)).to start_with("\e[33mSkipping missing location '")
      end
    end

    it 'syncup' do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      outl = out.lines
      # The spec tests set --no-progress, so each sync action gets reported.
      #expect(outl[0]).to eq("Adding item state\n")
      #expect(outl[1]).to eq("Adding item temperature\n")
      #expect(outl[2]).to eq("Adding item uptime\n")
      #expect(outl[3]).to eq("Adding item humidity\n")
      (0..3).each { |ln| expect(outl[ln]).to start_with('Adding item ') }
      expect(outl[4]).to eq("Updating product resources\n")
      # Windows is insane:
      #   "Adding item ........................Administrator.AppData.Local.Temp.2.d20170913-3860-pgji6g.project.modules.table_util\n"
      #expect(outl[5]).to eq("Adding item table_util\n")
      expect(outl[5]).to start_with('Adding item ')
      expect(outl[5]).to end_with("table_util\n")
      #expect(outl[6]).to eq("Updating item c3juj9vnmec000000_event\n")
      # The order isn't always consistent, so just do start_with.
      #expect(outl[7]).to eq("Updating item timer_timer\n")
      #expect(outl[8]).to eq("Updating item user_account\n")
      #expect(outl[9]).to eq("Updating item tsdb_exportJob\n")
      (6..9).each { |ln| expect(outl[ln]).to start_with('Updating item ') }
      #expect(outl[10]).to eq("Adding item POST_/api/fire\n")
      #expect(outl[11]).to eq("Adding item PUT_/api/fire/{code}\n")
      #expect(outl[12]).to eq("Adding item DELETE_/api/fire/{code}\n")
      #expect(outl[13]).to eq("Adding item GET_/api/onfire\n")
      #expect(outl[14]).to eq("Adding item /icon.png\n")
      #expect(outl[15]).to eq("Adding item /\n")
      #expect(outl[16]).to eq("Adding item /js/script.js\n")
      (10..16).each { |ln| expect(outl[ln]).to start_with('Adding item ') }
      verify_err_missing_location(err)
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      #expect(out).to start_with(%(Adding:\nDeleting:\nChanging:\n))
      #expect(out).to start_with(%(Nothing to add\nNothing to delete\nNothing to change\n))
      expect(out).to start_with(%(Nothing new locally\nNothing new remotely\nNothing that differs\n))
      # Due to timestamp races, there might be modules or services in Changing.
      #expect(err).to eq('')
      verify_err_missing_location(err)
      expect(status.exitstatus).to eq(0)
    end
  end

  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

