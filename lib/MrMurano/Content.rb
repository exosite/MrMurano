# Last Modified: 2017.09.29 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'uri'
require 'cgi'
require 'net/http'
require 'mime/types'
require 'digest'
require 'http/form_data'
require 'MrMurano/Config'
require 'MrMurano/http'
require 'MrMurano/verbosing'
require 'MrMurano/SolutionId'
require 'MrMurano/SyncAllowed'
require 'MrMurano/SyncUpDown'

module MrMurano
  ## The details of talking to the Content service.
  module Content
    class Base
      include Http
      include Verbose
      include SolutionId
      include SyncAllowed

      def initialize
        @solntype = 'product.id'
        @uriparts_apidex = 1
        init_api_id!
        @uriparts = [:service, @api_id, :content, :item]
        @itemkey = :id
        #@locationbase = $cfg['location.base']
        @location = nil
      end

      ## Generate an endpoint in Murano
      # Uses the uriparts and path
      # @param path String: any additional parts for the URI
      # @return URI: The full URI for this enpoint.
      def endpoint(path='')
        super
        parts = [$cfg['net.protocol'] + ':/', $cfg['net.host'], 'api:1'] + @uriparts
        s = parts.map(&:to_s).join('/')
        URI(s + path.to_s)
      end

      # List of what is in the content area?
      def list
        get('?full=true')
        # MAYBE/2017-08-17:
        #   ret = get('?full=true')
        #   return [] unless ret.is_a?(Array)
        #   sort_by_name(ret)
      end

      # Delete Everything in you content area
      def clear_all
        delete('')
      end

      # Get details of a single item in content area
      # @param name [String] Name of content
      def fetch(name)
        get("/#{CGI.escape(name)}")
      end
      alias info fetch

      # Upload content to area.
      # @param name [String] Name of content to be uploaded.
      # @param local_path [String, Pathname] The file to upload
      # @param tags [Hash] Extra meta to attach to this file.
      def upload(name, local_path, tags=nil)
        # This is a two step process.
        # 1: Get the post instructions for S3.
        # 2: Upload to S3.

        # ?tags=CGI.escape(meta.to_json)
        # ?type=
        sha256 = Digest::SHA256.new
        sha256.file(local_path.to_s)
        mime = MIME::Types.type_for(local_path.to_s)[0] || MIME::Types['application/octet-stream'][0]

        params = {
          sha256: sha256.hexdigest,
          expires_in: 30,
          type: mime,
        }
        params[:tags] = tags.to_json if !tags.nil? && tags.is_a?(Hash)

        return unless upload_item_allowed(name)

        ret = get("/#{CGI.escape(name)}/upload?#{URI.encode_www_form(params)}")
        debug "POST instructions: #{ret}"
        raise "Method isn't POST!!!" unless ret.is_a?(Hash) && ret[:method] == 'POST'
        raise "EncType isn't multipart/form-data" unless ret[:enctype] == 'multipart/form-data'

        uri = URI(ret[:url])
        request = Net::HTTP::Post.new(uri)
        file = HTTP::FormData::File.new(local_path.to_s, content_type: mime)
        form = HTTP::FormData.create(ret[:inputs].merge(ret[:field] => file))

        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
        request.content_type = form.content_type
        request.content_length = form.content_length
        request.body = form.to_s

        if $cfg['tool.curldebug']
          a = []
          a << %(curl -s)
          a << %(-H 'User-Agent: #{request['User-Agent']}')
          a << %(-X #{request.method})
          a << %('#{request.uri}')
          ret[:inputs].each_pair do |key, value|
            a << %(-F '#{key}=#{value}')
          end
          a << %(-F #{ret[:field]}=@#{local_path})
          if $cfg.curlfile_f.nil?
            puts a.join(' ')
          else
            $cfg.curlfile_f << a.join(' ') + "\n\n"
            $cfg.curlfile_f.flush
          end
        end

        return if $cfg['tool.dry']
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |ihttp|
          response = ihttp.request(request)
          case response
          # rubocop:disable Lint/EmptyWhen
          # "Avoid when branches without a body."
          # "I'm going to allow this."
          when Net::HTTPSuccess
            # pass
          else
            showHttpError(request, response)
          end
        end
      end

      # Remove content by name
      # @param name [String] Name of content to be deleted
      def remove(name)
        return unless remove_item_allowed(name)
        delete("/#{CGI.escape(name)}")
      end

      # Download content
      # @param name [String] Name of content to be downloaded
      # @param block [Block] Block to process data as it is downloaded
      def download(name, &block)
        return unless download_item_allowed(name)
        # This is a two step process.
        # 1: Get the get instructions for S3.
        # 2: fetch from S3.
        ret = get("/#{CGI.escape(name)}/download")
        debug "GET instructions: #{ret}"
        raise "Method isn't GET!!!" unless ret.is_a?(Hash) && ret[:method] == 'GET'

        uri = URI(ret[:url])
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"

        if $cfg['tool.curldebug']
          a = []
          a << %(curl -s)
          a << %(-H 'User-Agent: #{request['User-Agent']}')
          a << %(-X #{request.method})
          a << %('#{request.uri}')
          if $cfg.curlfile_f.nil?
            puts a.join(' ')
          else
            $cfg.curlfile_f << a.join(' ') + "\n\n"
            $cfg.curlfile_f.flush
          end
        end

        return if $cfg['tool.dry']
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |ihttp|
          ihttp.request(request) do |response|
            case response
            when Net::HTTPSuccess
              if block_given?
                response.read_body(&block)
              else
                response.read_body do |chunk|
                  $stdout.write chunk
                end
              end
            else
              showHttpError(request, response)
            end
          end
        end
      end
    end
  end
end

