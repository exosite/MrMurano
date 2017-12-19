# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'

require 'highline/import'

require 'cmd_common'

RSpec.describe 'murano help', :cmd do
  include_context 'CI_CMD'

  context 'using subshell' do
    it 'no args' do
      out, err, status = Open3.capture3(capcmd('murano'))
      expect(err).to eq('')
      expect(out).to_not eq('')
      expect(status.exitstatus).to eq(0)
    end

    it 'as --help' do
      out, err, status = Open3.capture3(capcmd('murano', '--help'))
      expect(err).to eq('')
      expect(out).to_not eq('')
      expect(status.exitstatus).to eq(0)
    end
  end

  context 'using commander' do
    it 'no args' do
      #cmd_verify_help('help')
      stdout, stderr = murano_command_run('help')
      # The :help command gets processed by optparse, since we did
      # not call run!, and optparse looks at $0, which is 'rspec'.
      expect(strip_color(stdout)).to start_with(
        "  NAME:\n\n    #{File.basename $PROGRAM_NAME}\n\n  DESCRIPTION:\n\n    "
      )
      expect(stderr).to eq('')
    end

    it 'as --help' do
      stdout, stderr = murano_command_wont_parse('help', '--help')
      # See comment above; optparse uses $0, or 'rspec'.
      expect(strip_color(stdout)).to start_with(
        "Usage: #{File.basename $PROGRAM_NAME} [options]\n"
      )
      expect(stderr).to eq('')
    end

    # The version flag is processed in ::Commander::Runner.instance.run!,
    # which we're not calling, and if we try to test it here, optparse
    # ends up trying to handle it and barfs when it cannot find parser.ver
    #it 'cannot test version' do
    #  #stdout, stderr = murano_command_run('-v')
    #  #stdout, stderr = murano_command_run('help', '-v')
    #  #stdout, stderr = murano_command_run('help', '--version')
    #end
  end
end

