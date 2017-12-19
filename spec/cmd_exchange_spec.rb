# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'

require 'cmd_common'
require 'MrMurano/Config'

RSpec.describe 'murano exchange', :cmd, :needs_password do
  include_context 'CI_CMD'

  context 'without project' do
    it 'help' do
      cmd_verify_help('exchange')
    end
  end

  context 'with project' do
    #before(:example) { project_up }
    #after(:example) { project_down }

    def expect_exchange_element_table(stdout, stderr, num_cols: nil)
      expect(stderr).to eq('')
      lines = stdout.lines
      # FIXME/2017-08-29: Is this too much detail??
      #   What about running test once, dumping output to file,
      #   and expecting same output next time?
      expect(lines[0]).to match(/^Found [\d]+ elements.$/)
      # Outline of table. n columns. '+-----+-----+---...----+\n'
      expect(lines[1]).to match(/^(\+-+){#{num_cols}}\+$/)
      # Header.
      expect(lines[2]).to match(/^\| elementId/)
      # Separator.
      expect(lines[3]).to match(/^(\+-+){#{num_cols}}\+$/)
      # Content. Starts with elementId.
      (4..(lines.length - 2)).to_a.each do |line|
        expect(lines[line]).to match(/^\| [0-9a-f]+ \| /)
      end
      expect(lines[-1]).to match(/^(\+-+){#{num_cols}}\+$/)
    end

    context 'list' do
      it 'as table' do
        stdout, stderr = murano_command_run('exchange list')
        # 4 columns: elementId, name, status, description.
        expect_exchange_element_table(stdout, stderr, num_cols: 4)
      end

      it 'only ids' do
        stdout, stderr = murano_command_run('exchange list', '--idonly')
        expect(stderr).to eq('')
        stdout.lines.each do |line|
          expect(line).to match(/^[0-9a-f]+$/)
        end
      end

      it 'fewer fields' do
        stdout, stderr = murano_command_run('exchange list', '--brief')
        # 3 columns: elementId, name, status.
        expect_exchange_element_table(stdout, stderr, num_cols: 3)
      end

      it 'as json' do
        stdout, stderr = murano_command_run('exchange list', '-c', 'outformat=json')
        expect(stderr).to eq('')
        expect { JSON.parse(stdout) }.to_not raise_error
        #expect(status.exitstatus).to eq(0)
      end

      it 'output to file' do
        stdout, stderr = murano_command_run('exchange list', '--idonly', '-o', 'bob')
        expect(stderr).to eq('')
        expect(stdout).to eq('')
        #expect(status.exitstatus).to eq(0)
        expect(File.exist?('bob')).to be true
        data = IO.read('bob')
        expect(data).to match(/^(\S+\s)*\S+$/)
      end

      context 'purchase' do
        # MAYBE/TESTME/2017-08-30: Cannot functional test 'exchange purchase'
        # of 'available' element because you cannot un-add elements (you'd
        # have to create a new business). We could add a unit test of
        # MrMurano::Exchange.purchase, though. But it's just 4 statements,
        # and the functional test here for adding an already added element
        # also tests that same function. So probably no need to add test.

        it 'is ambiguous name' do
          # MEH/2017-08-31: This test is dependent on the platform having
          # more than one element with the term 'IoT' in its name!
          stdout, stderr = murano_command_exits('exchange purchase', 'IoT')
          expect(stdout).to eq('')
          expect(stderr).to a_string_starting_with(
            'Please be more specific: More than one matching element was found: '
          )
        end

        it 'is already added ID' do
          element_name = 'Timer Service'
          stdout, _stderr = murano_command_run('exchange list', element_name, '--idonly')
          element_id = stdout.strip
          stdout, stderr = murano_command_exits('exchange purchase', element_id)
          expect(stdout).to eq('')
          expect(strip_fancy(stderr)).to eq(
            "The specified element has already been purchased: '#{element_name}' (#{element_id})\n"
          )
        end
      end
    end
  end
end

