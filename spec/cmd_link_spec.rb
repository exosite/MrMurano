# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'

require 'cmd_common'
require 'MrMurano/Config'

RSpec.describe 'murano link', :cmd, :needs_password do
  include_context 'CI_CMD'

  context 'without project' do
    it 'help' do
      cmd_verify_help('link')
    end

    # 2017-08-30: The next two tests show the difference between using a
    # subshell to run murano commands versus running them directly. The
    # latter method lets us get coverage of the command modules.
    context 'subshell vs inline' do
      context 'using subshell' do
        it 'will not list' do
          out, err, status = Open3.capture3(capcmd('murano', 'link', 'list'))
          expect(strip_color(out)).to eq(MrMurano::Config::INVALID_PROJECT_HINT + "\n")
          expecting = %(The "link list" command only works in a Murano project.\n)
          expect(strip_color(err)).to eq(expecting)
          expect(status.exitstatus).to eq(1)
        end
      end

      context 'using commander' do
        it 'will not list' do
          stdout, stderr = murano_command_run('link list')
          expect(stdout).to eq(MrMurano::Config::INVALID_PROJECT_HINT + "\n")
          expect(stderr).to eq(
            %(The "link list" command only works in a Murano project.\n)
          )
        end
      end
    end
  end

  context 'with project' do
    before(:example) { project_up(skip_link: true) }
    after(:example) { project_down }

    it 'links and lists' do
      out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
      #expect(out).to a_string_starting_with("Linked product #{@solz_name}")
      olines = out.lines

      expect(strip_fancy(olines[0])).to eq(
        "Linked '#{@proj_name_prod}' to '#{@proj_name_appy}'\n"
      )

      expect(olines[1]).to eq("Created default event handler\n")
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'assign', 'list'))
      expect(err).to eq('')
      olines = out.lines
      expect(olines[0]).to match(/^(\+-+){3}\+$/)
      expect(olines[1]).to match(/^\| name\s+\| script_key\s+\| service\s+\|$/)
      expect(olines[2]).to match(/^(\+-+){3}\+$/)
      expect(olines[-1]).to match(/^(\+-+){3}\+$/)
      expect(status.exitstatus).to eq(0)
    end

    it 'unlinks' do
      out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
      #expect(out).to a_string_starting_with("Linked product #{@solz_name}")
      olines = out.lines
      expect(strip_fancy(olines[0])).to eq(
        "Linked '#{@proj_name_prod}' to '#{@proj_name_appy}'\n"
      )
      expect(olines[1]).to eq("Created default event handler\n")
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'link', 'unset'))
      #expect(out).to a_string_starting_with("Unlinked #{@solz_name}")
      # E.g.,
      #   Unlinked ‘linktest3e7def1b86a1d680’ from ‘linktest3e7def1b86a1d680’\n
      #   Removed ‘h2thqll2z9sqoooc0_w4w3vxla11ngg4cok_event’ from ‘linktest3e7def1b86a1d680\n
      olines = out.lines
      expect(strip_fancy(olines[0])).to eq(
        "Unlinked '#{@proj_name_prod}' from '#{@proj_name_appy}'\n"
      )
      expect(strip_fancy(olines[1])).to a_string_starting_with(%(Removed '))
      expect(strip_fancy(olines[1])).to match(
        /^Removed '[_a-z0-9]*' from '#{@proj_name_appy}'\n$/
      )
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
    end
  end
end

