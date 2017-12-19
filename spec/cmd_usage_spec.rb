# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'cmd_common'

RSpec.describe 'murano usage', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    # NOTE: The usage command works on one or more solutions of any type.
    @product_name = rname('usageTest')

    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solutions', 'expunge', '--yes'))
    expect(out).to eq("Deleted 2 solutions\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  def confirm_usage_table(olines, ix)
    expect(olines[ix + 0]).to match(%r{^(Product|Application): usage[tT]est[a-z0-9]+ <[a-z0-9]+> https://[.a-z0-9]+$})
    expect(olines[ix + 1]).to match(/^(\+-+){5}\+$/)
    expect(olines[ix + 2]).to match(/^\|\s+\| Quota\s+\| Daily\s+\| Monthly\s+\| Total\s+\|$/)
    # Beneath the header row is a splitter line.
    expect(olines[ix + 3]).to match(/^(\+-+){5}\+$/)
    ix += 4
    # Beneath the splitter line are 1 or more rows, one for each service.
    loop do
      if olines[ix].start_with? '+-'
        # Closing table line.
        break
      end
      expect(olines[ix]).to match(/^| [a-z0-9_]+\s+(|\s+[0-9]*\s+){4}|$/)
      ix += 1
    end
    expect(olines[ix]).to match(/^(\+-+){5}\+$/)
    ix += 1
  end

  it 'show usage' do
    out, err, status = Open3.capture3(capcmd('murano', 'usage'))
    expect(err).to eq('')
    olines = out.lines
    ix = 0
    ix = confirm_usage_table(olines, ix)
    _ix = confirm_usage_table(olines, ix)
    expect(status.exitstatus).to eq(0)
  end
end

