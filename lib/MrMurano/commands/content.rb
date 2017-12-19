# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'pathname'
require 'MrMurano/Content'
require 'MrMurano/ReCommander'

command :content do |c|
  c.syntax = %(murano content)
  c.summary = %(About Content Area)
  c.description = %(
This set of commands let you interact with the content area for a product.

This is where OTA data can be stored so that devices can easily download it.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'content list' do |c|
  c.syntax = %(murano content list)
  c.summary = %(List downloadable content for a product)
  c.description = %(
List downloadable content for a product.

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  ).strip

  c.option '-l', '--long', %(Include more info for each file)

  c.action do |args, options|
    c.verify_arg_count!(args)

    prd = MrMurano::Content::Base.new

    MrMurano::Verbose.whirly_start 'Looking for content...'
    items = prd.list
    exit 2 if items.nil?
    MrMurano::Verbose.whirly_stop
    if !items.empty?
      prd.outf(items) do |dd, ios|
        if options.long
          headers = %i[Name Size 'Last Modified' MIME]
          rows = dd.map { |d| [d[:id], d[:length], d[:last_modified], d[:type]] }
        else
          headers = %i[Name Size]
          rows = dd.map { |d| [d[:id], d[:length]] }
        end
        prd.tabularize({ headers: headers, rows: rows }, ios)
      end
    else
      prd.warning 'Did not find any content'
    end
  end
end

command 'content info' do |c|
  c.syntax = %(murano content info <content name>)
  c.summary = %(Show more info for a content item)
  c.description = %(
Show more info for a content item.

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  ).strip

  c.action do |args, _options|
    c.verify_arg_count!(args, 1, ['Missing <content name>'])
    prd = MrMurano::Content::Base.new
    info = prd.info(args[0])
    prd.outf(info) do |dd, ios|
      ios.puts Hash.transform_keys_to_strings(dd).to_yaml
    end
  end
end

command 'content delete' do |c|
  c.syntax = %(murano content delete <content name>)
  c.summary = %(Delete a content item)
  c.description = %(
Delete a content item.

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  ).strip

  c.option('-y', '--[no-]yes', %(Answer "yes" to all prompts and run non-interactively))

  c.action do |args, options|
    c.verify_arg_count!(args, 1, ['Missing <content name>'])
    prd = MrMurano::Content::Base.new
    prd.cmd_confirm_delete!(args[0], options.yes, 'abort!')
    ret = prd.remove(args[0])
    prd.outf(ret) if !ret.nil? && ret.count > 1
  end
end

command 'content upload' do |c|
  tags = {}
  c.syntax = %(murano content upload <file>)
  c.summary = %(Upload content)
  c.description = %(
Upload a content item.

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  ).strip

  c.option('--tags KEY=VALUE', %(Add extra meta info to the content item)) do |ec|
    key, value = ec.split('=', 2)
    # a=b :> ["a","b"]
    # a= :> ["a",""]
    # a :> ["a"]
    raise "Bad tag key '#{param}'" if key.to_s.empty?
    raise "Bad tag value '#{param}'" if value.to_s.empty?
    key = key.downcase if key.casecmp('name').zero?
    tags[key] = value
  end

  c.action do |args, options|
    c.verify_arg_count!(args, 1, ['Missing <file>'])
    options.default meta: ' '

    prd = MrMurano::Content::Base.new

    name = ::File.basename(args[0])
    name = tags['name'] if tags.key? 'name'
    if name.to_s.empty?
      prd.error 'Bad file name'
      exit 2
    end

    tags = nil if tags.empty?
    prd.upload(name, args[0], tags)
  end
end

command 'content download' do |c|
  c.syntax = %(murano content download <content name>)
  c.summary = %(Download a content item)
  c.description = %(
Download a content item.

Data uploaded to a product's content area can be downloaded by devices using
the HTTP Device API.
  ).strip

  c.option '-o', '--output FILE', %(Save content to a file)

  c.action do |args, options|
    c.verify_arg_count!(args, 1, ['Missing <content name>'])
    prd = MrMurano::Content::Base.new
    if options.output.nil?
      prd.download(args[0]) # to stdout
    else
      out_file = Pathname.new(options.output)
      out_file.open('w') do |io|
        prd.download(args[0]) do |chunk|
          io << chunk
        end
      end
    end
  end
end

