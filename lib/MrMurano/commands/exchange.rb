# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'highline'
require 'MrMurano/verbosing'
require 'MrMurano/Exchange'
require 'MrMurano/ReCommander'
require 'MrMurano/commands/business'

# *** Business commands: Exchange Elements
# ----------------------------------------

command :exchange do |c|
  c.syntax = %(murano exchange)
  c.summary = %(About IOT Exchange)
  c.description = %(
Commands for working with IOT Exchange.
  ).strip
  c.project_not_required = true
  c.subcmdgrouphelp = true

  c.action do |_args, _options|
    ::Commander::UI.enable_paging unless $cfg['tool.no-page']
    say MrMurano::SubCmdGroupHelp.new(c).get_help
  end
end

command 'exchange list' do |c|
  c.syntax = %(murano exchange list [--options] [<name-or-ID>])
  c.summary = %(List Exchange Elements)
  c.description = %(
List Exchange Elements, either all of them, or those that are purchased or available.

Each Exchange Element is identified by an Element ID and a name.

Element status:

- added       An Element that has been added to and enabled for your Business

- available   An Element that can be added to and enabled for your Business

- available*  An Element that you can use if you upgrade your Business tier

  ).strip
  c.project_not_required = true

  cmd_table_output_add_options(c)

  c.option '--[no-]added', 'Only show Elements that have been added to the Application'
  c.option '--[no-]full', 'Show all fields'
  c.option '--[no-]other', 'Show other fields: like type, tiers, tags, and action, and apiServiceName'

  # Add --id and --name options.
  cmd_options_add_id_and_name(c)

  c.action do |args, options|
    c.verify_arg_count!(args, 1)
    cmd_defaults_id_and_name(options)

    xchg = MrMurano::Exchange.new
    xchg.must_business_id!

    elems, available, purchased = find_elements(xchg, options, args[0])
    if options.added.nil?
      show = elems
    elsif options.added
      show = purchased
    else
      show = available
    end

    headers, pruned = cmd_exchange_header_and_elems(show, options)

    io = File.open(options.output, 'w') if options.output
    xchg.outf(pruned, io) do |item, ios|
      if options.idonly
        ios.puts item
      else
        ios.puts "Found #{pruned.length} elements."
        xchg.tabularize(
          {
            headers: headers.map(&:to_s),
            rows: item,
          },
          ios,
        )
      end
    end
    io.close unless io.nil?
  end
end
alias_command 'exchange list available', 'exchange list', '--no-added'
alias_command 'exchange list purchased', 'exchange list', '--added'

def find_elements(xchg, options, term)
  filter_id = nil
  filter_name = nil
  filter_fuzzy = nil
  if term
    if options.id
      filter_id = term
    elsif options.name
      filter_name = term
    else
      filter_fuzzy = term
    end
  end
  xchg.elements(filter_id: filter_id, filter_name: filter_name, filter_fuzzy: filter_fuzzy)
end

def cmd_exchange_header_and_elems(elems, options)
  # MAYBE/2017-08-31: If you `-c outformat=json`, each Element is a
  # list of values, rather than a dictionary. Wouldn't the JSON be
  # easier to consume if each Element was a dict, rather than list?
  if options.idonly
    headers = %i[elementId]
    elems = elems.map(&:elementId)
  elsif options.brief
    headers = %i[elementId name]
    headers += [:status] unless options.added
    #elems = elems.map { |elem| [elem.elementId, elem.name] }
    elems = elems.map { |elem| headers.map { |key| elem.send(key) } }
  elsif options.full
    headers = %i[elementId name status type apiServiceName tiers tags actions markdown]
    all_hdrs = (elems[0] && elems[0].meta.keys) || []
    all_hdrs.each do |chk|
      headers.push(chk) unless headers.include?(chk)
    end
    #elems = elems.map { |elem| headers.map { |key| elem.meta[key] } }
    elems = elems.map { |elem| headers.map { |key| elem.send(key) || '' } }
  elsif options.other
    # NOTE: Showing columns not displayed when --other not specified,
    #   except not showing :markdown, ever.
    headers = %i[elementId type apiServiceName tiers tags actions]
    #headers = %i[elementId type apiServiceName tiers tags actions markdown]
    #elems = elems.map { |elem| headers.map { |key| elem.send(key) } }
    elems = elems.map do |elem|
      [
        elem.elementId,
        elem.type,
        elem.apiServiceName,
        #elem.tiers,
        #elem.tiers.join(' | '),
        elem.tiers.join("\n"),
        #elem.tags,
        #elem.tags.join(' | '),
        elem.tags.join("\n"),
        #elem.actions,
        elem.actions.map { |actn| actn.map { |key, val| "#{key}: #{val}" }.join("\n") }.join("\n"),
        #elem.markdown.gsub("\n", '\\n'),
      ]
    end
  else
    # 2017-08-28: There are 9 keys, and one of them -- :markdown -- is a
    # lot of text, so rather than, e.g., elems[0].meta.keys, be selective.
    headers = %i[elementId name]
    headers += [:status] unless options.added
    headers += [:description]
    if $stdout.tty?
      # Calculate how much room (how many characters) are left for the
      # description column.
      width_taken = 0
      # rubocop:disable Performance/FixedSize
      #   "Do not compute the size of statically sized objects."
      width_taken += '| '.length
      # Calculate the width of each column except the last (:description).
      headers[0..-2].each do |key|
        elem_with_max = elems.max { |a, b| a.send(key).length <=> b.send(key).length }
        width_taken += elem_with_max.send(key).length unless elem_with_max.nil?
        width_taken += ' | '.length
      end
      width_taken += ' | '.length
      term_width, _rows = HighLine::SystemExtensions.terminal_size
      width_avail = term_width - width_taken
      # MAGIC_NUMBER: Tweak/change this if you want. 20 char min feels
      # about right: don't wrap if column would be narrow or negative.
      width_avail = nil if width_avail < 20
    else
      width_avail = nil
    end
    #elems = elems.map { |elem| headers.map { |key| elem.send(key) } }
    elems = elems.map do |elem|
      headers.map do |key|
        if !width_avail.nil? && key == :description
          #elem.meta[key].scan(/.{1,#{width_avail}}/).join("\n")
          full = elem.send(key)
          parts = []
          until full.empty?
            # Split the description on a space before the max width.
            # FIXME/2017-08-28: Need to test really long desc with no space.
            part = full[0..width_avail]
            full = full[(width_avail + 1)..-1] || ''
            leftover = ''
            part, _space, leftover = part.rpartition(' ') unless full.empty?
            if part.empty?
              part = leftover.to_s
              leftover = ''
            else
              full = leftover.to_s + full
              full = full
            end
            parts.push(part.strip)
          end
          parts.join("\n")
        else
          elem.send(key)
        end
      end
    end
  end
  [headers, elems]
end

command 'exchange purchase' do |c|
  c.syntax = %(murano exchange purchase [--options] <name-or-ID>)
  c.summary = %(Add an Exchange Element to your Business)
  c.description = %(
Add an Exchange Element to your Business.
  ).strip
  # It feels a little weird to not require a project, but all
  # we need is the Business ID; this action does not apply to
  # solutions.
  c.project_not_required = true

  # Add --id and --name options.
  cmd_options_add_id_and_name(c)

  c.action do |args, options|
    c.verify_arg_count!(args, 1, ['Missing Element name or ID'])
    cmd_defaults_id_and_name(options)

    xchg = MrMurano::Exchange.new
    xchg.must_business_id!

    # If the user specifies filter_id, we could try to fetch that Element
    # directly (e.g., by calling exchange/<bizId>/element/<elemId>),
    # but the response doesn't specify if the Element is purchased or not.
    # So we grab everything from /element/ and /purchase/.

    elems, _available, purchased = find_elements(xchg, options, args[0])
    if elems.length > 1
      idents = elems.map { |elem| "#{xchg.fancy_ticks(elem.name)} (#{elem.elementId})" }
      idents[-1] = 'and ' + idents[-1]
      xchg.warning(
        'Please be more specific: More than one matching element was found: ' \
        "#{idents.join(', ')}"
      )
      exit 2
    elsif elems.empty?
      xchg.warning('No matching element was found.')
      exit 2
    elsif purchased.length == 1
      # I.e., elems.status == :added
      xchg.warning(
        'The specified element has already been purchased: ' \
        "#{xchg.fancy_ticks(purchased[0].name)} (#{purchased[0].elementId})"
      )
      exit 2
    elsif elems.first.status == :upgrade
      xchg.warning('Please upgrade your Business to add this Element. Visit:')
      xchg.warning('  https://www.exosite.io/business/settings/upgrade')
      exit 2
    end

    xchg.purchase(elems.first.elementId)
  end
end
alias_command 'exchange add', 'exchange purchase'
alias_command 'exchange buy', 'exchange purchase'

