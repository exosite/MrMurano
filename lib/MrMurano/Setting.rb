# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'MrMurano/verbosing'

module MrMurano
  class Setting
    include Verbose

    SERVICE_MAP = {
      'Device2' => 'Gateway',
    }.freeze

    ## Map service names into actual class names.
    #
    # Some of the service names have changed over time and no longer match the class
    # names that implement them. This maps them back, as well as correcting casing.
    #
    # @param service [String] User facing service name
    # @return [String] Internal class name for service
    def mapservice(service)
      service = service.to_s.downcase
      SERVICE_MAP.each_pair do |k, v|
        return v if [k.downcase, v.downcase].include? service
      end
      # rubocop:disable Style/PerlBackrefs: "Avoid the use of Perl-style backrefs."
      # Because of the upcase, we cannot just call, e.g.,
      #   service.sub(/(.)(.*)/, "\\1\\2")
      service.sub(/(.)(.*)/) { "#{$1.upcase}#{$2.downcase}" }
    end

    def read(service, setting)
      debug %(Looking up class "MrMurano::#{mapservice(service)}::Settings")
      gb = Object.const_get("MrMurano::#{mapservice(service)}::Settings").new
      meth = setting.to_sym
      debug %(Looking up method "#{meth}")
      return gb.__send__(meth) if gb.respond_to?(meth)
      error "Unknown setting '#{setting}' on '#{service}'"
    rescue NameError => e
      error %(No Settings on "#{service}")
      if $cfg['tool.debug']
        error e.message
        error e.to_s
      end
    end

    def write(service, setting, value)
      debug %(Looking up class "MrMurano::#{mapservice(service)}::Settings")
      gb = Object.const_get("MrMurano::#{mapservice(service)}::Settings").new
      meth = "#{setting}=".to_sym
      debug %(Looking up method "#{meth}")
      return gb.__send__(meth, value) if gb.respond_to? meth
      error "Unknown setting '#{setting}' on '#{service}'"
    rescue NameError => e
      error %(No Settings on "#{service}")
      if $cfg['tool.debug']
        error e.message
        error e.to_s
      end
    end

    ##
    # List all Settings classes and the accessors on them.
    #
    # This is for letting users know which things can be read and written in the
    # settings command.
    def list
      result = {}
      ::MrMurano.constants.each do |maybe|
        begin
          gb = Object.const_get("MrMurano::#{maybe}::Settings")
          result[maybe] = gb.instance_methods(false).reject { |i| i.to_s[-1] == '=' }
        # rubocop:disable Lint/HandleExceptions: Do not suppress exceptions."
        rescue StandardError
          # EXPLAIN/2017-08-20: When/Why does this happen?
        end
      end
      result
      # MAYBE/2017-08-17:
      #   sort_by_name(result)
    end
  end
end

