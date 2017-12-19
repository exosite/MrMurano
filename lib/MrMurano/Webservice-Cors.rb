# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'yaml'
require 'MrMurano/Webservice'

module MrMurano
  module Webservice
    class Settings < WebserviceBase
      def initialize
        super
        @uriparts << :cors
      end

      def cors
        ret = get
        return {} unless ret.is_a?(Hash) && !ret.key?(:error)
        ret
      end

      def cors=(x)
        raise 'Not Hash' unless x.is_a? Hash
        put('', x)
      end
    end

    class Cors < WebserviceBase
      def initialize
        super
        @uriparts << :cors
        #@project_section = :cors
      end

      def fetch(_id=nil)
        ret = get
        return [] unless ret.is_a?(Hash) && !ret.key?(:error)
        if ret.key?(:cors)
          # XXX cors is a JSON encoded string. That seems weird. keep an eye on this.
          data = JSON.parse(ret[:cors], @json_opts)
        else
          data = ret
        end
        if block_given?
          yield Hash.transform_keys_to_strings(data).to_yaml
        else
          data
        end
      end

      ##
      # Upload CORS
      # @param file [String,Nil] File path to upload other than defaults
      def upload(file=nil)
        if !file.nil?
          data = YAML.load_file(file)
        else
          file = $project['routes.cors']
          # If it is just a string, then is a file to load.
          if file.is_a? String
            data = YAML.load_file(file)
          else
            data = file
            file = %(ProjectFile['routes.cors'])
          end
        end
        return unless upload_item_allowed(file)
        put('', data)
      end
    end
  end
end

