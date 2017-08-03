# Last Modified: 2017.07.26 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'json'
require 'net/http'
require 'pp'
require 'uri'
require 'MrMurano/SyncRoot'
require 'MrMurano/Webservice'

module MrMurano
  # …/endpoint
  module Webservice
    class Endpoint < WebserviceBase

      # Route Specific details on an Item
      class RouteItem < Item
        # @return [String] HTTP method for this endpoint
        attr_accessor :method
        # @return [String] path for URL maps to this endpoint
        attr_accessor :path
        # @return [String] Acceptable Content-Type for this endpoint
        attr_accessor :content_type
        # ???? What is this?
        attr_accessor :use_basic_auth
      end

      def initialize
        super
        @uriparts << 'endpoint'
        @project_section = :routes
        @match_header = /--#ENDPOINT (?<method>\S+) (?<path>\S+)( (?<ctype>.*))?/
      end

      def self.description
        %(Endpoints)
      end

      ##
      # This gets all data about all endpoints
      def list
        ret = get()
        return [] if ret.is_a?(Hash) and ret.has_key?(:error)
        ret.map do |item|
          if item[:content_type].to_s.empty? then
            item[:content_type] = 'application/json'
          end
          # XXX should this update the script header?
          RouteItem.new(item)
        end
      end

      def fetch(id)
        ret = get('/' + id.to_s)
        ret[:content_type] = 'application/json' if ret[:content_type].empty?

        script = ret[:script].lines.map{|l|l.chomp}

        aheader = (script.first or "")

        rh = ['--#ENDPOINT', ret[:method].upcase, ret[:path]]
        rh << ret[:content_type] if ret[:content_type] != 'application/json'
        rheader = rh.join(' ')

        # if header is missing add it.
        # If header is wrong, replace it.

        md = @match_header.match(aheader)
        if md.nil? then
          # header missing.
          script.unshift rheader
        elsif md[:method] != ret[:method] or
          md[:path] != ret[:path] or
          md[:ctype] != ret[:content_type] then
          # header is wrong.
          script[0] = rheader
        end
        # otherwise current header is good.

        script = script.join("\n") + "\n"
        if block_given? then
          yield script
        else
          script
        end
      end

      ##
      # Upload endpoint
      # @param local [Pathname] path to file to push
      # @param remote [RouteItem] of method and endpoint path
      # @param modify [Boolean] True if item exists already and this is changing it
      def upload(local, remote, modify)
        local = Pathname.new(local) unless local.kind_of? Pathname
        raise "no file" unless local.exist?
        # we assume these are small enough to slurp.
        if remote.script.nil? then
          script = local.read
          remote[:script] = script
        end
        limitkeys = [:method, :path, :script, :content_type, @itemkey]
        remote = remote.to_h.select{|k,v| limitkeys.include? k }
        #      post('', remote)
        if remote.has_key? @itemkey then
          put('/' + remote[@itemkey], remote) do |request, http|
            response = http.request(request)
            case response
            when Net::HTTPSuccess
              #return JSON.parse(response.body)
            when Net::HTTPNotFound
              verbose "\tDoesn't exist, creating"
              post('/', remote)
            else
              showHttpError(request, response)
            end
          end
        else
          verbose "\tNo itemkey, creating"
          post('', remote)
        end
      end

      ##
      # Delete an endpoint
      def remove(id)
        delete('/' + id.to_s)
      end

      def tolocalname(item, key)
        name = ''
        # 2017-07-02: Changing shovel operator << to +=
        # to support Ruby 3.0 frozen string literals.
        name += item[:path].split('/').reject { |i| i.empty? }.join('-')
        name += '.'
        # This downcase is just for the filename.
        name += item[:method].downcase
        name += '.lua'
      end

      def to_remote_item(from, path)
        # Path could be have multiple endpoints in side, so a loop.
        items = []
        path = Pathname.new(path) unless path.kind_of? Pathname
        cur = nil
        lineno = 0
        path.readlines().each do |line|
          md = @match_header.match(line)
          if not md.nil? then
            # header line.
            cur[:line_end] = lineno unless cur.nil?
            items << cur unless cur.nil?
            # VERIFY/2017-07-03: The syncdown test is revealing a
            #   problem with casing. The original file has a lowercase
            #   HTTP verb, e.g., "post". This is what syncup uploaded.
            #   But on murano status, the local route's method is upcased
            #   in memory, so the status command says the route is diff.
            #   But on murano diff, MurCLI makes two local temp files
            #   to execute the diff, and it also upcases the method in
            #   both files, so the diff runs clean!
            #   VERIFY/2017-07-03: [lb] adding upcase here; hope that works!
            #   OHOHOH/2017-07-03: [lb] also recreating the header line.
            up_line = "--#ENDPOINT #{md[:method].upcase} #{md[:path]}"
            up_line += " #{md[:ctype]}" unless md[:ctype].to_s.empty?
            up_line += "\n"
            cur = RouteItem.new(
              #method: md[:method],
              method: md[:method].upcase,
              path: md[:path],
              content_type: (md[:ctype] or 'application/json'),
              local_path: path,
              line: lineno,
              script: up_line,
            )
          elsif not cur.nil? and not cur[:script].nil? then
            # 2017-07-02: Frozen string literal: change << to +=
            cur[:script] += line
          end
          lineno += 1
        end
        cur[:line_end] = lineno unless cur.nil?
        items << cur unless cur.nil?
        items
      end

      def match(item, pattern)
        # Pattern is: #{method}#{path glob}
        pattern_pattern = /^#(?<method>[^#]*)#(?<path>.*)/i
        md = pattern_pattern.match(pattern)
        return false if md.nil?
        debug "match pattern: '#{md[:method]}' '#{md[:path]}'"

        unless md[:method].empty? then
          return false unless item[:method].casecmp(md[:method]).zero?
        end

        return true if md[:path].empty?

        ::File.fnmatch(md[:path],item[:path])
      end

      def synckey(item)
        "#{item[:method].upcase}_#{item[:path]}"
      end

      def docmp(itemA, itemB)
        if itemA[:script].nil? and itemA[:local_path] then
          itemA[:script] = itemA[:local_path].read
        end
        if itemB[:script].nil? and itemB[:local_path] then
          itemB[:script] = itemB[:local_path].read
        end
        return (itemA[:script] != itemB[:script] or itemA[:content_type] != itemB[:content_type])
      end
    end

    SyncRoot.instance.add('endpoints', Endpoint, 'A', true)
  end
end

