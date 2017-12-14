# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'json'
require 'open3'
require 'os'
require 'rbconfig'

require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('statusTest')
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @applctn_name = rname('statusTest')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    #out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #olines = out.lines
    #expect(olines[0]).to eq("Linked ‘#{@product_name}’ to ‘#{@applctn_name}’\n")
    #expect(olines[1]).to eq("Created default event handler\n")
    #expect(err).to eq('')
    #expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(
      #capcmd('murano', 'syncdown', '--eventhandlers', '--no-delete', '--no-update')
      capcmd('murano', 'syncdown', '--eventhandlers', '--no-delete', '--no-create')
    )
    # E.g.,
    #  "Adding item timer_timer\nAdding item tsdb_exportJob\nAdding item user_account\n"
    olines = out.lines
    # 2017-08-08: Because of eventhandler.undeletable, the boilerplate items
    #   pre-exist, in a sense, and are therefore described as being updated,
    #   not added.
    (0..2).each do |ln|
      #expect(olines[ln].to_s).to a_string_starting_with('Adding item ')
      expect(olines[ln].to_s).to a_string_starting_with('Updating item ')
    end

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

  def match_syncable_contents(slice)
    expect(slice).to include(
      a_string_matching(%r{ \+ \w  .*modules/table_util\.lua}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua:4}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua:7}),
      # singleRoute only appears in some of the tests.
      a_string_matching(%r{ \+ \w  .*routes/singleRoute\.lua}),
      a_string_matching(%r{ \+ \w  .*files/js/script\.js}),
      a_string_matching(%r{ \+ \w  .*files/icon\.png}),
      a_string_matching(%r{ \+ \w  .*files/index\.html}),
    )
  end

  def match_syncable_contents_resources(slice)
    expect(slice).to include(
      a_string_matching(/ \+ \w  state/),
      a_string_matching(/ \+ \w  temperature/),
      a_string_matching(/ \+ \w  uptime/),
      a_string_matching(/ \+ \w  humidity/),
    )
  end

  def match_syncable_contents_except_single_route(slice)
    expect(slice).to include(
      a_string_matching(%r{ \+ \w  .*modules/table_util\.lua}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua:4}),
      a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua:7}),
      # singleRoute does not appear in old Solutionfile tests
      # that don't specify it.
      #a_string_matching(%r{ \+ \w  .*routes/singleRoute\.lua}),
      a_string_matching(%r{ \+ \w  .*files/js/script\.js}),
      a_string_matching(%r{ \+ \w  .*files/icon\.png}),
      a_string_matching(%r{ \+ \w  .*files/index\.html}),
    )
  end

  def match_remote_boilerplate_v1_0_0_service(slice)
    expect(slice).to include(
      #a_string_matching(%r{ - \w  device2_event}),
      #a_string_matching(%r{ - \w  interface_addGatewayResource}),
      #a_string_matching(%r{ - \w  interface_addIdentity}),
      #a_string_matching(%r{ - \w  interface_clearContent}),
      #a_string_matching(%r{ - \w  interface_deleteContent}),
      #a_string_matching(%r{ - \w  interface_downloadContent}),
      #a_string_matching(%r{ - \w  interface_getGatewayResource}),
      #a_string_matching(%r{ - \w  interface_getGatewaySettings}),
      #a_string_matching(%r{ - \w  interface_getIdentity}),
      #a_string_matching(%r{ - \w  interface_getIdentityState}),
      #a_string_matching(%r{ - \w  interface_infoContent}),
      #a_string_matching(%r{ - \w  interface_listContent}),
      #a_string_matching(%r{ - \w  interface_listIdentities}),
      #a_string_matching(%r{ - \w  interface_makeIdentity}),
      #a_string_matching(%r{ - \w  interface_removeGatewayResource}),
      #a_string_matching(%r{ - \w  interface_removeIdentity}),
      #a_string_matching(%r{ - \w  interface_setIdentityState}),
      #a_string_matching(%r{ - \w  interface_updateGatewayResource}),
      #a_string_matching(%r{ - \w  interface_updateGatewaySettings}),
      #a_string_matching(%r{ - \w  interface_updateIdentity}),
      #a_string_matching(%r{ - \w  interface_uploadContent}),
      #a_string_matching(%r{ - \w  timer_timer (Application Event Handlers)}),
      #a_string_matching(%r{ - \w  tsdb_exportJob (Application Event Handlers)}),
      #a_string_matching(%r{ - \w  user_account (Application Event Handlers)}),
      #a_string_matching(%r{ - \w  timer_timer}),
      #a_string_matching(%r{ - \w  tsdb_exportJob}),
      #a_string_matching(%r{ - \w  user_account}),
      a_string_matching(/ M \w  timer_timer\.lua/),
      a_string_matching(/ M \w  tsdb_exportJob\.lua/),
      a_string_matching(/ M \w  user_account\.lua/),
    )
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

    it 'status' do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Two problems with this output.
      # 1: Order of files is not set
      # 2: Path prefixes could be different.
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_resources(olines[1..4])
      match_syncable_contents(olines[5..12])
      #expect(olines[13]).to eq("Only on remote server:\n")
      expect(olines[13]).to eq("Nothing new remotely\n")
      # FIMXE/2017-06-23: We should DRY this long list which is same in each test.
      # FIXME/2017-06-23: The interfaces the server creates for a new project
      #   will problem vary depending on what modules are loaded, and are likely
      #   to change over time...
      #match_remote_boilerplate_v1_0_0_service(olines[14..35])

      # NOTE: On Windows, touch doesn't work, so items differ.
      # Check the platform, e.g., 'linux-gnu', or other.
      # 2017-07-14 08:51: Is there a race condition here? [lb] saw
      # differences earlier, but then not after adding this...
      #is_windows = (
      #  RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      #)
      #if OS.windows?
      #  expect(olines[14]).to eq("Items that differ:\n")
      #  expect(olines[15..16]).to contain_exactly(
      #    a_string_matching(%r{ M \w  .*services/timer_timer\.lua}),
      #    a_string_matching(%r{ M \w  .*services/tsdb_exportJob\.lua}),
      #  )
      #else
      expect(olines[14]).to eq("Nothing that differs\n")
      #end

      expect(status.exitstatus).to eq(0)
    end

    it 'matches file path', :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '**/icon.png'))
      expect(err).to eq('')
      expect(out.lines).to match(
        [
          "Only on local machine:\n",
          a_string_matching(%r{ \+ \w  .*files/icon\.png}),
          "Nothing new remotely\n",
          "Nothing that differs\n",
        ]
      )
      expect(status.exitstatus).to eq(0)
    end

    it 'matches route', :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '#put#'))
      expect(err).to eq('')
      expect(out.lines).to match(
        [
          "Only on local machine:\n",
          a_string_matching(%r{ \+ \w  .*routes/manyRoutes\.lua:4}),
          "Nothing new remotely\n",
          "Nothing that differs\n",
        ]
      )
      expect(status.exitstatus).to eq(0)
    end
  end

  context 'with ProjectFile' do
    before(:example) do
      # We previously called syncdown, which created the project/services/
      # directory, but don't fret, this copy command will overlay files and
      # it will not overwrite directories (or do nothing to them, either).
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml',
      )
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
    end

    it 'status' do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_resources(olines[1..4])
      match_syncable_contents(olines[5..12])
      expect(olines[13]).to eq("Nothing new remotely\n")

      # NOTE: On Windows, touch doesn't work, so items differ.
      # Check the platform, e.g., 'linux-gnu', or other.
      #is_windows = (
      #  RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      #)
      if OS.windows?
        expect(olines[14]).to eq("Items that differ:\n")
        expect(olines[15..16]).to include(
          a_string_matching(%r{ M \w  .*services/timer_timer\.lua}),
          a_string_matching(%r{ M \w  .*services/tsdb_exportJob\.lua}),
        )
      else
        expect(olines[14]).to eq("Nothing that differs\n")
      end

      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context 'with Solutionfile 0.2.0' do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml'
      )
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          default_page: 'index.html',
          file_dir: 'files',
          custom_api: 'routes/manyRoutes.lua',
          modules: {
            table_util: 'modules/table_util.lua',
          },
          event_handler: {
            device: {
              datapoint: 'services/devdata.lua',
            },
          },
        }.to_json
      end
    end

    it 'status' do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Not a single match, because the order of items within groups can shift
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_resources(olines[1..4])
      match_syncable_contents_except_single_route(olines[5..11])
      #expect(olines[12]).to eq("Only on remote server:\n")
      #match_remote_boilerplate_v1_0_0_service(olines[13..15])
      expect(olines[12]).to eq("Nothing new remotely\n")
      #expect(olines[16]).to eq("Nothing that differs\n")
      ##expect(olines[11]).to eq("Items that differ:\n")
      ##expect(olines[12..12]).to contain_exactly(
      ##  a_string_matching(%r{ M \w  .*services/devdata\.lua}),
      ##)
      expect(olines[13]).to eq("Items that differ:\n")
      match_remote_boilerplate_v1_0_0_service(olines[14..16])
      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context 'with Solutionfile 0.3.0' do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml',
      )
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          default_page: 'index.html',
          assets: 'files',
          routes: 'routes/manyRoutes.lua',
          # Note that singleRoute.lua is not included, so it won't be seen by status command.
          modules: {
            table_util: 'modules/table_util.lua',
          },
          services: {
            device: {
              datapoint: 'services/devdata.lua',
            },
          },
          version: '0.3.0',
        }.to_json
      end
    end

    it 'status' do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      # pp out.split "\n"
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_resources(olines[1..4])
      match_syncable_contents_except_single_route(olines[5..11])
      #expect(olines[12]).to eq("Only on remote server:\n")
      #match_remote_boilerplate_v1_0_0_service(olines[13..15])
      expect(olines[12]).to eq("Nothing new remotely\n")
      #expect(olines[16]).to eq("Nothing that differs\n")
      expect(olines[13]).to eq("Items that differ:\n")
      match_remote_boilerplate_v1_0_0_service(olines[14..16])
      expect(status.exitstatus).to eq(0)
    end
  end
end

