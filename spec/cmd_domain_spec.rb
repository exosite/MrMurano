# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'cmd_common'

RSpec.describe 'murano domain', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('domainTest')
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
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @product_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'delete', @product_name, '--yes'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'show domain' do
    out, err, status = Open3.capture3(capcmd('murano', 'domain'))
    # 2017-05-31: Previously, the project could be named whatever and
    #   the URI would start with the same.
    #     expect(out.chomp).to start_with("#{@product_name.downcase}.apps.exosite").and end_with('.io')
    #   Now, it's: <ID>.m2.exosite.io, where ID is of the form, 'j41fj45hhk82so0os'
    # Is there an expected length? [lb] has seen {16,17}
    #expect(out.split('.', 2)[0]).to match(/^[a-zA-Z0-9]{16,17}$/)
    #expect(out.chomp).to end_with('m2.exosite.io')
    out.lines.each do |line|
      expect(line).to match(
        %r{^(Product|Application): domain[Tt]est[a-z0-9]+ <[a-z0-9]+> https://[.a-z0-9]+$}
      )
    end
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end
end

