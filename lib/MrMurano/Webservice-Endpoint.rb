# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'net/http'
require 'pathname'
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
        @uriparts << :endpoint
        @project_section = :routes
        @match_header = /--#ENDPOINT (?<method>\S+) (?<path>\S+)( (?<ctype>.*))?/
      end

      def self.description
        # 2017-08-07: UI and ProjectFile call these "Routes". Let's be consistent.
        # 2017-08-14: UI team says "Route" changing to "Endpoint" in new UI.
        #%(Route)
        %(Endpoint)
      end

      ##
      # This gets all data about all endpoints.
      def list
        ret = get
        return [] unless ret.is_a?(Array)
        ret.map do |item|
          if item[:content_type].to_s.empty?
            item[:content_type] = 'application/json'
          end
          # XXX should this update the script header?
          RouteItem.new(item)
        end
        # MAYBE/2017-08-17:
        #   ret.map! ...
        #   sort_by_name(ret)
      end

      def fetch(id)
        ret = get('/' + id.to_s)
        unless ret.is_a?(Hash) && !ret.key?(:error)
          error "#{UNEXPECTED_TYPE_OR_ERROR_MSG}: #{ret}"
          ret = {}
        end

        ret[:content_type] = 'application/json' if ret[:content_type].empty?

        add_terminating_nl = ret[:script].end_with? "\n"
        script = ret[:script].lines.map(&:chomp)

        aheader = (script.first || '')

        rh = ['--#ENDPOINT', ret[:method].upcase, ret[:path]]
        rh << ret[:content_type] if ret[:content_type] != 'application/json'
        rheader = rh.join(' ')

        # if header is missing add it.
        # If header is wrong, replace it.

        md = @match_header.match(aheader)
        if md.nil?
          # header missing.
          script.unshift rheader
        elsif (
          md[:method] != ret[:method] ||
          md[:path] != ret[:path] ||
          md[:ctype] != ret[:content_type]
        )
          # header is wrong.
          script[0] = rheader
        end
        # otherwise current header is good.

        script = script.join("\n")
        script += "\n" if add_terminating_nl
        if block_given?
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
      def upload(local, remote, _modify)
        local = Pathname.new(local) unless local.is_a? Pathname
        # MAYBE/2017-09-07: Honor options.ignore_errors here?
        raise 'no file' unless local.exist?
        # we assume these are small enough to slurp.
        if remote.script.nil?
          script = local.read
          remote[:script] = script
        end
        limitkeys = [:method, :path, :script, :content_type, @itemkey]
        remote = remote.to_h.select { |k, _v| limitkeys.include? k }
        if remote.key? @itemkey
          return unless upload_item_allowed(remote[@itemkey])
          put('/' + remote[@itemkey], remote) do |request, http|
            response = http.request(request)
            case response
            when Net::HTTPSuccess
              #return JSON.parse(response.body)
              return
            when Net::HTTPNotFound
              verbose "\tDoesn't exist, creating"
              post('/', remote)
            else
              showHttpError(request, response)
            end
          end
        else
          verbose "\tNo itemkey, creating"
          #return unless upload_item_allowed(remote)
          return unless upload_item_allowed(local)
          post('', remote)
        end
      end

      ##
      # Delete an endpoint
      def remove(id)
        return unless remove_item_allowed(id)
        delete('/' + id.to_s)
      end

      def tolocalname(item, _key)
        name = ''
        # 2017-07-02: Changing shovel operator << to +=
        # to support Ruby 3.0 frozen string literals.
        name += item[:path].split('/').reject(&:empty?).join('-')
        name += '.'
        # This downcase is just for the filename.
        name += item[:method].downcase
        name += '.lua'
        name
      end

      def to_remote_item(_from, path)
        # Path could be have multiple endpoints in side, so a loop.
        items = []
        path = Pathname.new(path) unless path.is_a? Pathname
        cur = nil
        lineno = 0
        path.readlines.each do |line|
          md = @match_header.match(line)
          if !md.nil?
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
              content_type: (md[:ctype] || 'application/json'),
              local_path: path,
              line: lineno,
              script: up_line,
            )
          elsif !cur.nil? && !cur[:script].nil?
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

        unless md[:method].empty?
          return false unless item[:method].casecmp(md[:method]).zero?
        end

        return true if md[:path].empty?

        ::File.fnmatch(md[:path], item[:path])
      end

      def synckey(item)
        "#{item[:method].upcase}_#{item[:path]}"
      end

      def docmp(item_a, item_b)
        if item_a[:script].nil? && item_a[:local_path]
          item_a[:script] = item_a[:local_path].read
        end
        if item_b[:script].nil? && item_b[:local_path]
          item_b[:script] = item_b[:local_path].read
        end
        (item_a[:script] != item_b[:script] || item_a[:content_type] != item_b[:content_type])
      end
    end

    SyncRoot.instance.add('endpoints', Endpoint, 'E', true, %w[routes])
  end
end

