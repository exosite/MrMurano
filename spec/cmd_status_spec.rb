# Last Modified: 2017.07.27 /coding: utf-8
# frozen_string_literal: probably not yet

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'json'
require 'open3'
require 'pathname'
require 'rbconfig'

require 'cmd_common'

RSpec.describe 'murano status', :cmd, :needs_password do
  include_context "CI_CMD"

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
      capcmd('murano', 'syncdown', '--eventhandlers', '--no-delete', '--no-update')
    )
    # E.g.,
    #  "Adding item timer_timer\nAdding item tsdb_exportJob\nAdding item user_account\n"
    olines = out.lines
    expect(olines[0]).to a_string_starting_with("Adding item ")
    expect(olines[1]).to a_string_starting_with("Adding item ")
    expect(olines[2]).to a_string_starting_with("Adding item ")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  def match_syncable_contents(slice)
      expect(slice).to include(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        # singleRoute only appears in some of the tests.
        a_string_matching(/ \+ A  .*routes\/singleRoute\.lua/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
      )
  end

  def match_syncable_contents_resources(slice)
      expect(slice).to include(
        a_string_matching(/ \+ T  state \(Resources\)/),
        a_string_matching(/ \+ T  temperature \(Resources\)/),
        a_string_matching(/ \+ T  uptime \(Resources\)/),
        a_string_matching(/ \+ T  humidity \(Resources\)/),
      )
  end

  def match_syncable_contents_except_singleRoute(slice)
      expect(slice).to include(
        a_string_matching(/ \+ M  .*modules\/table_util\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:7/),
        # singleRoute does not appear in old Solutionfile tests
        # that don't specify it.
        #a_string_matching(/ \+ A  .*routes\/singleRoute\.lua/),
        a_string_matching(/ \+ S  .*files\/js\/script\.js/),
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        a_string_matching(/ \+ S  .*files\/index\.html/),
      )
  end

  def match_remote_boilerplate_v1_0_0_service(slice)
    expect(slice).to contain_exactly(
      #" - E  device2_event\n",
      #" - E  interface_addGatewayResource\n",
      #" - E  interface_addIdentity\n",
      #" - E  interface_clearContent\n",
      #" - E  interface_deleteContent\n",
      #" - E  interface_downloadContent\n",
      #" - E  interface_getGatewayResource\n",
      #" - E  interface_getGatewaySettings\n",
      #" - E  interface_getIdentity\n",
      #" - E  interface_getIdentityState\n",
      #" - E  interface_infoContent\n",
      #" - E  interface_listContent\n",
      #" - E  interface_listIdentities\n",
      #" - E  interface_makeIdentity\n",
      #" - E  interface_removeGatewayResource\n",
      #" - E  interface_removeIdentity\n",
      #" - E  interface_setIdentityState\n",
      #" - E  interface_updateGatewayResource\n",
      #" - E  interface_updateGatewaySettings\n",
      #" - E  interface_updateIdentity\n",
      #" - E  interface_uploadContent\n",
      " - E  timer_timer (Application Event Handlers)\n",
      " - E  tsdb_exportJob (Application Event Handlers)\n",
      " - E  user_account (Application Event Handlers)\n",
    )
  end

  context "without ProjectFile" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml',
      )
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Two problems with this output.
      # 1: Order of files is not set
      # 2: Path prefixes could be different.
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents(olines[1..8])
      match_syncable_contents_resources(olines[9..12])
      #expect(olines[13]).to eq("Only on remote server:\n")
      expect(olines[13]).to eq("Nothing new remotely\n")
      # FIMXE/2017-06-23: We should DRY this long list which is same in each test.
      # FIXME/2017-06-23: The interfaces the server creates for a new project
      #   will problem vary depending on what modules are loaded, and are likely
      #   to change over time...
      #match_remote_boilerplate_v1_0_0_service(olines[14..35])

      # NOTE: On Windows, touch doesn't work, so items differ.
      # Check the platform, e.g., "linux-gnu", or other.
      # 2017-07-14 08:51: Is there a race condition here? [lb] saw
      # differences earlier, but then not after adding this...
      #is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
      #if is_windows
      #  expect(olines[14]).to eq("Items that differ:\n")
      #  expect(olines[15..16]).to contain_exactly(
      #    a_string_matching(/ M E  .*services\/timer_timer\.lua/),
      #    a_string_matching(/ M E  .*services\/tsdb_exportJob\.lua/),
      #  )
      #else
        expect(olines[14]).to eq("Nothing that differs\n")
      #end

      expect(status.exitstatus).to eq(0)
    end

    it "matches file path", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '**/icon.png'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Only on local machine:\n",
        a_string_matching(/ \+ S  .*files\/icon\.png/),
        "Nothing new remotely\n",
        "Nothing that differs\n",
      ])
      expect(status.exitstatus).to eq(0)
    end

    it "matches route", :broken_on_windows do
      out, err, status = Open3.capture3(capcmd('murano', 'status', '#put#'))
      expect(err).to eq('')
      expect(out.lines).to match([
        "Only on local machine:\n",
        a_string_matching(/ \+ A  .*routes\/manyRoutes\.lua:4/),
        "Nothing new remotely\n",
        "Nothing that differs\n",
      ])
      expect(status.exitstatus).to eq(0)
    end
  end

  context "with ProjectFile" do
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

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents(olines[1..8])
      match_syncable_contents_resources(olines[9..12])
      expect(olines[13]).to eq("Nothing new remotely\n")

      # NOTE: On Windows, touch doesn't work, so items differ.
      # Check the platform, e.g., "linux-gnu", or other.
      is_windows = (RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/)
      if is_windows
        expect(olines[14]).to eq("Items that differ:\n")
        expect(olines[15..16]).to include(
          a_string_matching(/ M E  .*services\/timer_timer\.lua/),
          a_string_matching(/ M E  .*services\/tsdb_exportJob\.lua/),
        )
      else
        expect(olines[14]).to eq("Nothing that differs\n")
      end

      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context "with Solutionfile 0.2.0" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml')
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :file_dir => 'files',
          :custom_api => 'routes/manyRoutes.lua',
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :event_handler => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          }
        }.to_json
      end
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      expect(err).to eq('')
      # Not a single match, because the order of items within groups can shift
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_except_singleRoute(olines[1..7])
      match_syncable_contents_resources(olines[8..11])
      expect(olines[12]).to eq("Only on remote server:\n")
      match_remote_boilerplate_v1_0_0_service(olines[13..15])
      expect(olines[16]).to eq("Nothing that differs\n")
      #expect(olines[11]).to eq("Items that differ:\n")
      #expect(olines[12..12]).to contain_exactly(
      #  a_string_matching(/ M E  .*services\/devdata\.lua/),
      #)
      expect(status.exitstatus).to eq(0)
    end
  end

  # XXX wait, should a Solutionfile even work with Okami?
  context "with Solutionfile 0.3.0" do
    before(:example) do
      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets','files')
      FileUtils.mkpath('specs')
      FileUtils.copy(
        File.join(@testdir, 'spec/fixtures/product_spec_files/lightbulb.yaml'),
        'specs/resources.yaml',
      )
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :assets => 'files',
          :routes => 'routes/manyRoutes.lua',
          # Note that singleRoute.lua is not included, so it won't be seen by status command.
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :services => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          },
          :version => '0.3.0',
        }.to_json
      end
    end

    it "status" do
      out, err, status = Open3.capture3(capcmd('murano', 'status'))
      # pp out.split "\n"
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to eq("Only on local machine:\n")
      match_syncable_contents_except_singleRoute(olines[1..7])
      match_syncable_contents_resources(olines[8..11])
      expect(olines[12]).to eq("Only on remote server:\n")
      match_remote_boilerplate_v1_0_0_service(olines[13..15])
      expect(olines[16]).to eq("Nothing that differs\n")
      #expect(olines[15]).to eq("Items that differ:\n")
      #expect(olines[16..16]).to contain_exactly(
      #  a_string_matching(/ M E  .*services\/devdata\.lua/),
      #)
      expect(status.exitstatus).to eq(0)
    end
  end
end

