# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'json'
require 'time'
require 'highline'

module MrMurano
  module Pretties
    PRETTIES_COLORSCHEME = HighLine::ColorScheme.new do |cs|
      cs[:json] = [:magenta]
      cs[:record_type] = [:magenta]
      cs[:subject] = [:cyan]
      cs[:timestamp] = [:blue]
      cs[:tracking] = [:yellow]
    end
    HighLine.color_scheme = PRETTIES_COLORSCHEME

    # rubocop:disable Style/MethodName: "Use snake_case for method names."
    def self.makeJsonPretty(data, options, indent: nil, object_nl: nil)
      if options.pretty
        ret = JSON.pretty_generate(data, indent: indent, object_nl: object_nl).to_s
        ret[0] = HighLine.color(ret[0], :json)
        ret[-1] = HighLine.color(ret[-1], :json)
        ret
      else
        data.to_json
      end
    end

    # FIXME: (landonb): MUR-3081: Remove old http code for v3.1.0. Search: LOGS_USE_HTTP.
    def self.MakePrettyLogsV1(line, options)
      # 2017-07-02: Changing shovel operator << to +=
      # to support Ruby 3.0 frozen string literals.
      out = ''
      out += HighLine.color("#{line[:type] || '--'} ".upcase, :subject)
      out += HighLine.color("[#{line[:subject] || ''}]", :subject)
      out += ' '
      if line.key?(:timestamp)
        if line[:timestamp].is_a? Numeric
          if options.localtime
            curtime = Time.at(line[:timestamp]).localtime.strftime('%Y-%m-%d %H:%M:%S')
          else
            curtime = Time.at(line[:timestamp]).gmtime.strftime('%Y-%m-%d %H:%M:%S')
          end
        else
          curtime = line[:timestamp]
        end
      else
        curtime = '<no timestamp>'
      end
      out += HighLine.color(curtime, :timestamp)
      out += ":\n"
      if line.key?(:data)
        data = line[:data]

        if data.is_a?(Hash)
          if data.key?(:request) && data.key?(:response)
            out += "---------\nrequest:"
            out += makeJsonPretty(data[:request], options)

            out += "\n---------\nresponse:"
            out += makeJsonPretty(data[:response], options)
          else
            out += makeJsonPretty(data, options)
          end
        else
          out += data.to_s
        end

      else
        line.delete :type
        line.delete :timestamp
        line.delete :subject
        out += makeJsonPretty(line, options)
      end
      out
    end

    def self.MakePrettyLogsV2(line, options)
      out = log_pretty_assemble_header(line, options)
      out + log_pretty_assemble_body(line, options)
    end

    def self.fmt_text_padded(text, style, out, raw, options, min_width: 0)
      min_width = text.length + 3 unless options.align
      padding = min_width - text.length
      end
      padding = ' ' * (padding > 0 && padding || 0)
      out += HighLine.color(text, style) + padding
      raw += text + padding
      [out, raw]
    end

    def self.log_pretty_assemble_header(line, options)
      out = ''
      raw = ''
      out, raw = log_pretty_header_add_abbreviated_sev(line, out, raw, options)
      out, raw = log_pretty_header_add_log_record_type(line, out, raw, options)
      out, raw = log_pretty_header_add_event_timestamp(line, out, raw, options)
      out, raw = log_pretty_header_add_murano_tracking(line, out, raw, options)
      out, _raw = log_pretty_header_add_a_service_event(line, out, raw, options)
      out + "\n"
    end

    def self.log_pretty_header_add_abbreviated_sev(line, out, raw, options)
      fmt_abbreviated_severity(line[:severity], out, raw, options)
    end

    def self.log_pretty_header_add_loquacious_sev(line, out, raw, options)
      fmt_loquacious_severity(line[:severity], out, raw, options)
    end

    def self.fmt_abbreviated_severity(severity, out, raw, options, min_width: 7)
      abbrev, _loquac, style = styled_severity(severity)
      fmt_text_padded(abbrev, style, out, raw, options, min_width: min_width)
    end

    def self.fmt_loquacious_severity(severity, out, raw, options, min_width: 11)
      _abbrev, loquac, style = styled_severity(severity)
      fmt_text_padded(loquac, style, out, raw, options, min_width: min_width)
    end

    def self.styled_severity(severity)
      case severity
      when 0 # Emergency: system is unusable
        ['EMERG', 'EMERGENCY', %i[red bold on_white]]
      when 1 # Alert: action must be taken immediately
        ['ALERT', 'ALERT', %i[red bold]]
      when 2 # Critical: critical conditions
        ['CRIT', 'CRITICAL', %i[red bold]]
      when 3 # Error: error conditions
        ['ERROR', 'ERROR', %i[red]]
      when 4 # Warning: warning conditions
        ['WARN', 'WARNING', %i[yellow]]
      when 5 # Notice: normal but significant condition
        ['NOTE', 'NOTICE', %i[white]]
      when 6 # Informational: informational messages
        ['INFO', 'INFO', %i[blue]]
      when 7 # Debug: debug-level messages ]
        ['DEBUG', 'DEBUG', %i[green]]
      else
        ["????#{severity}", "????#{severity}", %i[red]]
      end
    end

    def self.log_pretty_header_add_log_record_type(line, out, raw, options)
      log_type = line[:type].to_s.empty? && '--' || line[:type]
      fmt_text_padded(log_type.upcase, :record_type, out, raw, options, min_width: 10)
    end

    def self.log_pretty_header_add_event_timestamp(line, out, raw, options)
      curtime = fmt_log_record_timestamp(line, options)
      min_width = curtime.length + 3
      fmt_text_padded(curtime, :timestamp, out, raw, options, min_width: min_width)
    end

    def self.fmt_log_record_timestamp(line, options)
      if line.key?(:timestamp)
        if line[:timestamp].is_a? Numeric
          time_secs_epoch = Time.at(line[:timestamp] / 1000.0)
          if options.localtime
            curtime = time_secs_epoch.localtime
          else
            curtime = time_secs_epoch.gmtime
          end
          format = options.sprintf
          format = '%Y-%m-%d %H:%M:%S' if format.to_s.empty?
          curtime = curtime.strftime(format)
        else
          curtime = line[:timestamp]
        end
      else
        curtime = '<no timestamp>'
      end
      curtime
    end

    def self.log_pretty_header_add_murano_tracking(line, out, raw, options)
      return [out, raw] unless options.tracking
      tid = line[:tracking_id].to_s.empty? && '--------' || line[:tracking_id].slice(0, 8)
      fmt_text_padded(tid, :tracking, out, raw, options, min_width: 11)
    end

    def self.log_pretty_header_add_a_service_event(line, out, raw, options)
      pad = options.align && '    ' || ''
      out += pad
      raw += pad
      svc_evt = []
      svc_evt += [line[:service]] unless line[:service].to_s.empty?
      svc_evt += [line[:event]] unless line[:event].to_s.empty?
      svc_evt = "[#{svc_evt.join(' ').upcase}]"
      fmt_text_padded(svc_evt, :subject, out, raw, options, min_width: 0)
    end

    def self.log_pretty_assemble_body(line, options)
      out = ''
      @body_prefix = options.indent && '  ' || ''
      out += log_pretty_assemble_message(line, options)
      out += log_pretty_assemble_data(line, options)
      out += log_pretty_assemble_remainder(line, options)
      out + log_pretty_assemble_tracking_id(line, options)
    end

    def self.log_pretty_assemble_message(line, _options)
      return '' unless line.key?(:message) && !line[:message].to_s.empty?
      @body_prefix + line[:message] + "\n"
    end

    def self.log_pretty_assemble_data(line, options)
      return '' unless line.key?(:data)
      data = line[:data]
      if data.is_a?(Hash)
        out = ''
        out += log_pretty_emphasize_entry(:request, data, options)
        out += log_pretty_emphasize_entry(:response, data, options)
        out + log_pretty_data_remainder(data, options)
      else
        data.to_s
      end
    end

    def self.log_pretty_emphasize_entry(entry, hash, options)
      return '' unless hash.key?(entry) && !hash[entry].empty?
      out = @body_prefix + "---------\n"
      out += @body_prefix + "#{entry}: "
      out += log_pretty_json(hash[entry], options)
      out + "\n"
    end

    def self.log_pretty_data_remainder(data, options)
      known_keys = %i[
        request
        response
      ]
      data = data.reject { |key, _val| known_keys.include?(key) }
      return '' if data.empty?
      out = @body_prefix + "---------\n"
      out + @body_prefix + 'data: ' + log_pretty_json(data, options) + "\n"
    end

    def self.log_pretty_assemble_remainder(line, options)
      known_keys = %i[
        severity
        type
        timestamp
        service
        event
        message
        tracking_id
        data
      ]
      line = line.reject { |key, _val| known_keys.include?(key) }
      return '' if line.empty?
      @body_prefix + log_pretty_json(line, options) + "\n"
    end

    def self.log_pretty_assemble_tracking_id(line, options)
      log_pretty_emphasize_entry(:tracking_id, line, options)
    end

    def self.log_pretty_json(hash, options)
      return '' if hash.empty?
      prefix = @body_prefix.to_s.empty? && '  ' || @body_prefix
      makeJsonPretty(
        hash, options, indent: prefix, object_nl: "\n" + @body_prefix
      )
    end
  end
end

