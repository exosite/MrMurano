# Last Modified: 2017.09.13 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'yaml'
require 'MrMurano/ReCommander'
require 'MrMurano/Webservice-Cors'

command :cors do |c|
  c.syntax = %(murano cors)
  c.summary = %(Get the CORS for the project.)
  c.description = %(
Get the CORS for the project.

Set the CORS with `murano cors set`.
  ).strip
  c.project_not_required = true

  c.example %(
    Output CORS parameters in an ASCII table.
  ).strip, 'murano cors'

  c.example %(
    Output CORS parameters as JSON.
  ).strip, 'murano cors --json'

  c.example %(
    Output CORS parameters in Yaml.
  ).strip, 'murano cors --yaml'

  c.example %(
    Output CORS parameters as comma-separated values.
  ).strip, 'murano cors --csv'

  c.example %(
    Output CORS parameters pretty-printed as a Ruby Hash.
  ).strip, 'murano cors --pp'

  c.action do |args, _options|
    c.verify_arg_count!(args)
    sol = MrMurano::Webservice::Cors.new
    ret = sol.fetch
    sol.outf(ret) do |obj, ios|
      # Called if tool.outformat is 'best' or 'csv' (not 'json', 'yaml', or 'pp').
      headers = obj.keys.sort
      row = []
      headers.each { |key| row << obj[key] }
      rows = [row]
      sol.tabularize({ headers: headers, rows: rows }, ios)
    end
  end
end

command 'cors set' do |c|
  c.syntax = %(murano cors set [<file>])
  c.summary = %(Set the CORS for the project)
  c.description = %(
Set the CORS for the project.
  ).strip
  c.project_not_required = true

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing <file>'])
    crs = MrMurano::Webservice::Cors.new
    file = args.shift
    crs.upload(file)
  end
end

