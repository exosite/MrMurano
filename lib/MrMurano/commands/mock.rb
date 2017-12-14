# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/Mock'
require 'MrMurano/ReCommander'

command :mock do |c|
  c.syntax = %(murano mock)
  c.summary = %(Enable or disable testpoint, or show current UUID)
  c.description = %(
The mock command lets you enable testpoints to do local Lua development.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'mock enable' do |c|
  c.syntax = %(murano mock enable)
  c.summary = %(Create a testpoint file)
  c.description = %(
Create a testpoint file.

Run syncup after running this to carry the change through to Murano.

Returns the UUID to be used for authenticating.
  ).strip
  c.option '--raw', %(print raw uuid)

  c.action do |args, options|
    c.verify_arg_count!(args)
    mock = MrMurano::Mock.new
    uuid = mock.create_testpoint
    if options.raw
      say uuid
    else
      say %(Created testpoint file. Run `murano syncup` to activate. The following is the authorization token:)
      say %($ export AUTHORIZATION="#{uuid}")
    end
  end
end

command 'mock disable' do |c|
  c.syntax = %(murano mock disable)
  c.summary = %(Remove the testpoint file)
  c.description = %(
Remove the testpoint file.

Run syncup after running this to carry the change through to Murano.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    mock = MrMurano::Mock.new
    removed = mock.remove_testpoint
    if removed
      say %(Deleted testpoint file. Run `murano syncup` to remove the testpoint.)
    else
      say %(No testpoint file to remove.)
    end
  end
end

command 'mock show' do |c|
  c.syntax = %(murano mock disable)
  c.summary = %(Remove the testpoint file)
  c.description = %(
Remove the testpoint file.

Run syncup after running this to carry the change through to Murano.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args)
    mock = MrMurano::Mock.new
    uuid = mock.show
    if uuid
      say uuid
    else
      say %(Could not find testpoint file or UUID in testpoint file.)
    end
  end
end

