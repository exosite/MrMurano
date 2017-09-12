require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano password', :cmd do
  include_context "CI_CMD"

  it "Lists when no file" do
    out, err, status = Open3.capture3(capcmd('murano', 'password', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){2}\+$/)
    expect(olines[1]).to match(/^\| Host\s+\| Username\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){2}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "sets a password" do
    out, err, status = Open3.capture3(capcmd('murano', 'password', 'set', 'bob@bob.bob', 'an.API.host.i', '--password', 'bad'))
    expect(err).to eq('')
    expect(out).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(capcmd('murano', 'password', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){2}\+$/)
    expect(olines[1]).to match(/^\| Host\s+\| Username\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){2}\+$/)
    expect(olines[3]).to match(/^\| an.API.host.i\s+\| bob@bob\.bob\s+\|$/)
    expect(olines[4]).to match(/^(\+-+){2}\+$/)
    expect(status.exitstatus).to eq(0)
  end

  it "deletes a password" do
    File.open(File.join(ENV['HOME'], '.murano', 'passwords'), 'w') do |io|
      io << "---\n"
      io << "an.API.host.i:\n"
      io << "  bob@bob.bob: badpassword\n"
      io << "  rich@er.u: notbetter\n"
    end
    out, err, status = Open3.capture3(capcmd('murano', 'password', 'delete', 'rich@er.u', 'an.API.host.i', '-y'))
    expect(err).to eq('')
    expect(out).to eq('')
    expect(status.exitstatus).to eq(0)


    out, err, status = Open3.capture3(capcmd('murano', 'password', 'list'))
    expect(err).to eq('')
    olines = out.lines
    expect(olines[0]).to match(/^(\+-+){2}\+$/)
    expect(olines[1]).to match(/^\| Host\s+\| Username\s+\|$/)
    expect(olines[2]).to match(/^(\+-+){2}\+$/)
    expect(olines[3]).to match(/^\| an.API.host.i\s+\| bob@bob\.bob\s+\|$/)
    expect(olines[4]).to match(/^(\+-+){2}\+$/)
    expect(status.exitstatus).to eq(0)
  end

end

#  vim: set ai et sw=2 ts=2 :
