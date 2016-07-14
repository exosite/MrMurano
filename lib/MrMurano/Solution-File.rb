require 'uri'
require 'net/http'
require 'net/http/post/multipart'
require 'digest/sha1'
require 'pp'

module MrMurano
  # …/file 
  class File < SolutionBase
    def initialize
      super
      @uriparts << 'file'
      @itemkey = :path
    end

    ##
    # Get a list of all of the static content
    def list
      get()
    end

    ##
    # Get one item of the static content.
    def fetch(path, &block)
      get(path) do |request, http|
        http.request(request) do |resp|
          case resp
          when Net::HTTPSuccess
            if block_given? then
              resp.read_body &block
            else
              resp.read_body do |chunk|
                $stdout.write chunk
              end
            end
          else
            say_error "got #{resp.to_s} from #{request} #{request.uri.to_s}"
            raise resp
          end
        end
        nil
      end
    end

    ##
    # Delete a file
    def remove(path)
      # TODO test
      delete('/'+path)
    end

    ##
    # Upload a file
    def upload(local, remote)
      local = Pathname.new(local) unless local.kind_of? Pathname

      # FIXME: bad request? why?
      uri = endPoint('upload' + remote[:path])
      upper = UploadIO.new(local.open('rb'), remote[:mime_type], local.basename)
			req = Net::HTTP::Put::Multipart.new(uri, 'file'=> upper )
      workit(req) do |request,http|
        request.delete 'Content-Type'

        response = http.request(request)
        case response
        when Net::HTTPSuccess
        else
          say_error "got #{response} from #{request} #{request.uri.to_s}"
          say_error ":: #{response.body}"
        end
      end
    end

    def tolocalname(item, key)
      name = item[key]
      name = $cfg['files.default_page'] if name == '/'
      name
    end

    def toremotename(from, path)
      name = super(from, path)
      name = '/' if name == $cfg['files.default_page']

      mime=`file -I -b #{path.to_s}`.chomp.sub(/;.*$/, '')
      mime='application/octect' if mime.nil?

      sha1 = Digest::SHA1.file(path.to_s).hexdigest

      {:path=>name, :mime_type=>mime, :checksum=>sha1}
    end

    def synckey(item)
      if item.has_key? :path then
        "#{item[:path]}_#{item[:checksum]}_#{item[:mime_type]}"
      else
        "#{item['path']}_#{item['checksum']}_#{item['mime_type']}"
      end
    end
  end


end
#  vim: set ai et sw=2 ts=2 :
