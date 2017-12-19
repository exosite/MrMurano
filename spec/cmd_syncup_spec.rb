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
    out, err, status = Open3.capture3(
      capcmd('murano', 'product', 'create', @product_name, '--save')
    )
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('syncupTestApp')
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
    expect(strip_fancy(olines[0]))
      .to eq("Linked '#{@product_name}' to '#{@applctn_name}'\n")
    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  after(:example) do
    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', @applctn_name, '-y')
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', @product_name, '-y')
    )
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
      #   Skipping missing location
      #     ‘/tmp/d20170809-7670-z315jn/project/services’ (Services)
      #   Skipping missing location
      #     ‘/tmp/d20170809-7670-z315jn/project/services’ (Interfaces)
      expect(elines).to(satisfy { |_v| elines.length == 2 })
      elines.each do |line|
        expect(strip_fancy(line)).to start_with("\e[33mSkipping missing location '")
      end
    end

    it 'syncup' do
      out, err, status = Open3.capture3(capcmd('murano', 'syncup'))
      outl = out.lines
      # The spec tests set --no-progress, so each sync action gets reported.
      (0..3).each { |ln| expect(outl[ln]).to start_with('Adding item ') }
      expect(outl[4]).to eq("Updating remote product resources\n")
      # Windows is insane:
      #   "Adding item ........................Administrator.AppData.Local.Temp.2.d20170913-3860-pgji6g.project.modules.table_util\n"
      # So we can't do this:
      #   expect(outl[5]).to eq("Adding item table_util\n")
      expect(outl[5]).to start_with('Adding item ')
      expect(outl[5]).to end_with("table_util\n")
      (6..7).each { |ln| expect(outl[ln]).to start_with('Removing item ') }
      (8..14).each { |ln| expect(outl[ln]).to start_with('Adding item ') }
      verify_err_missing_location(err)
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(out).to start_with(
        %(Nothing new locally\nNothing new remotely\nNothing that differs\n)
      )
      verify_err_missing_location(err)
      expect(status.exitstatus).to eq(0)
    end
  end

  # TODO: With ProjectFile
  # TODO: With Solutionfile 0.2.0
  # TODO: With Solutionfile 0.3.0
end

