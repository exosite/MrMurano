# Last Modified: 2017.07.20 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'certified' if Gem.win_platform?
require 'date'
require 'json'
require 'net/http'
require 'uri'
# 2017-06-07: [lb] getting "execution expired (Net::OpenTimeout)" on http.start.
# Suggestions online say to load the pure-Ruby DNS implementation, resolv.rb.
require 'resolv-replace'

module MrMurano
  module Http
    def token
      return @token if defined?(@token) && !@token.to_s.empty?
      acc = MrMurano::Account.instance
      @token = acc.token
      #raise 'Not logged in!' if @token.nil?
      if @token.nil?
        error 'Not logged in!'
        exit 1
      end
      # MAYBE: Check that ADC is enabled on the business. If not, tell
      #   user to run Murano 2.x. See adc_compat_check for comments.
      #acc.adc_compat_check
      @token
    end

    def json_opts
      return @json_opts unless not defined?(@json_opts) or @json_opts.nil?
      @json_opts = {
        :allow_nan => true,
        :symbolize_names => true,
        :create_additions => false
      }
    end

    def curldebug(request)
      if $cfg['tool.curldebug']
        formp = (request.content_type =~ %r{multipart/form-data})
        a = []
        a << %{curl -s}
        if request.key?('Authorization')
          a << %{-H 'Authorization: #{request['Authorization']}'}
        end
        a << %{-H 'User-Agent: #{request['User-Agent']}'}
        a << %{-H 'Content-Type: #{request.content_type}'} unless formp
        a << %{-X #{request.method}}
        a << %{'#{request.uri.to_s}'}
        unless request.body.nil?
          if formp
            m = request.body.match(
              %r{form-data;\s+name="(?<name>[^"]+)";\s+filename="(?<filename>[^"]+)"}
            )
            a << %{-F #{m[:name]}=@#{m[:filename]}} unless m.nil?
          else
            a << %{-d '#{request.body}'}
          end
        end
        if $cfg.curlfile_f.nil?
          puts a.join(' ')
        else
          $cfg.curlfile_f << a.join(' ') + "\n\n"
          $cfg.curlfile_f.flush
        end
      end
    end

    # Default endpoint unless Class overrides it.
    def endpoint(path)
      URI('https://' + $cfg['net.host'] + '/api:1/' + path.to_s)
    end

    def http
      uri = URI('https://' + $cfg['net.host'])
      if not defined?(@http) or @http.nil?
        @http = Net::HTTP.new(uri.host, uri.port)
        @http.use_ssl = true
        @http.start
      end
      @http
    end
    def http_reset
      @http = nil
    end

    def set_def_headers(request)
      request.content_type = 'application/json'
      request['Authorization'] = 'token ' + token
      request['User-Agent'] = "MrMurano/#{MrMurano::VERSION}"
      request
    end

    def isJSON(data)
      begin
        [true, JSON.parse(data, json_opts)]
      rescue
        [false, data]
      end
    end

    def showHttpError(request, response)
      if $cfg['tool.debug']
        puts "Sent #{request.method} #{request.uri.to_s}"
        request.each_capitalized{|k,v| puts "> #{k}: #{v}"}
        if request.body.nil?
        else
          puts ">> #{request.body[0..156]}"
        end
        puts "Got #{response.code} #{response.message}"
        response.each_capitalized{|k,v| puts "< #{k}: #{v}"}
      end
      isj, jsn = isJSON(response.body)
      resp = "Request Failed: #{response.code}: "
      if isj
        # 2017-07-02: Changing shovel operator << to +=
        # to support Ruby 3.0 frozen string literals.
        if $cfg['tool.fullerror']
          resp += JSON.pretty_generate(jsn)
        elsif jsn.kind_of? Hash
          resp += "[#{jsn[:statusCode]}] " if jsn.has_key? :statusCode
          resp += jsn[:message] if jsn.has_key? :message
        else
          resp += jsn.to_s
        end
      else
        resp += (jsn or 'nil')
      end
      # assuming verbosing was included.
      error resp
    end

    def workit(request, &block)
      curldebug(request)
      if block_given?
        yield request, http()
      else
        response = http().request(request)
        case response
        when Net::HTTPSuccess
          workit_response(response)
        else
          # One problem with mixins is initialization...
          unless defined?(@suppress_error) && @suppress_error
            showHttpError(request, response)
          end
          nil
        end
      end
    end

    def workit_response(response)
      return {} if response.body.nil?
      begin
        JSON.parse(response.body, json_opts)
      rescue
        response.body
      end
    end

    def get(path='', query=nil, &block)
      uri = endpoint(path)
      uri.query = URI.encode_www_form(query) unless query.nil?
      workit(set_def_headers(Net::HTTP::Get.new(uri)), &block)
    end

    def post(path='', body={}, &block)
      uri = endpoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def postf(path='', form={}, &block)
      uri = endpoint(path)
      req = Net::HTTP::Post.new(uri)
      set_def_headers(req)
      req.content_type = 'application/x-www-form-urlencoded; charset=utf-8'
      req.form_data = form
      workit(req, &block)
    end

    def put(path='', body={}, &block)
      uri = endpoint(path)
      req = Net::HTTP::Put.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def patch(path='', body={}, &block)
      uri = endpoint(path)
      req = Net::HTTP::Patch.new(uri)
      set_def_headers(req)
      req.body = JSON.generate(body)
      workit(req, &block)
    end

    def delete(path='', &block)
      uri = endpoint(path)
      workit(set_def_headers(Net::HTTP::Delete.new(uri)), &block)
    end
  end
end

# There is a bug where having TCP_NODELAY disabled causes connection issues
# with Murano. While ultimately the bug is Murano's, we need to work around
# here. As for Ruby, setting TCP_NODELAY was added in 2.1. But since the
# default version installed on MacOS is 2.0.0, we oftentimes hit it.
#
# So, if the current version of Ruby is 2.0.0, then use this bit of code
# copied from Ruby 2.1 (lib/net/http.rb, at line 868).

if RUBY_VERSION == '2.0.0'
  module Net
    class HTTP
      def connect
        if proxy?
          conn_address = proxy_address
          conn_port    = proxy_port
        else
          conn_address = address
          conn_port    = port
        end

        D "opening connection to #{conn_address}:#{conn_port}..."
        s = Timeout.timeout(@open_timeout, Net::OpenTimeout) {
          TCPSocket.open(conn_address, conn_port, @local_host, @local_port)
        }
        s.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        D "opened"
        if use_ssl?
          ssl_parameters = Hash.new
          iv_list = instance_variables
          SSL_IVNAMES.each_with_index do |ivname, i|
            if iv_list.include?(ivname) and
                value = instance_variable_get(ivname)
              ssl_parameters[SSL_ATTRIBUTES[i]] = value if value
            end
          end
          @ssl_context = OpenSSL::SSL::SSLContext.new
          @ssl_context.set_params(ssl_parameters)
          D "starting SSL for #{conn_address}:#{conn_port}..."
          s = OpenSSL::SSL::SSLSocket.new(s, @ssl_context)
          s.sync_close = true
          D "SSL established"
        end
        @socket = BufferedIO.new(s)
        @socket.read_timeout = @read_timeout
        @socket.continue_timeout = @continue_timeout
        @socket.debug_output = @debug_output
        if use_ssl?
          begin
            if proxy?
              # 2017-07-02: Changing shovel operator << to +=
              # to support Ruby 3.0 frozen string literals.
              buf = "CONNECT #{@address}:#{@port} HTTP/#{HTTPVersion}\r\n"
              buf += "Host: #{@address}:#{@port}\r\n"
              if proxy_user
                credential = ["#{proxy_user}:#{proxy_pass}"].pack('m')
                credential.delete!("\r\n")
                buf += "Proxy-Authorization: Basic #{credential}\r\n"
              end
              buf += "\r\n"
              @socket.write(buf)
              HTTPResponse.read_new(@socket).value
            end
            # Server Name Indication (SNI) RFC 3546
            s.hostname = @address if s.respond_to? :hostname=
            if @ssl_session and
                Time.now < @ssl_session.time + @ssl_session.timeout
              s.session = @ssl_session if @ssl_session
            end
            Timeout.timeout(@open_timeout, Net::OpenTimeout) { s.connect }
            if @ssl_context.verify_mode != OpenSSL::SSL::VERIFY_NONE
              s.post_connection_check(@address)
            end
            @ssl_session = s.session
          rescue => exception
            D "Conn close because of connect error #{exception}"
            @socket.close if @socket and not @socket.closed?
            raise exception
          end
        end
        on_connect
      end
    end
  end
end

