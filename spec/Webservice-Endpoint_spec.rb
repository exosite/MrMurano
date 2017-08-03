require 'tempfile'
require '_workspace'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Webservice-Endpoint'

RSpec.describe MrMurano::Webservice::Endpoint do
  include_context "WORKSPACE"
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['application.id'] = 'XYZ'

    @srv = MrMurano::Webservice::Endpoint.new
    allow(@srv).to receive(:token).and_return("TTTTTTTTTT")

    @baseURI = "https://bizapi.hosted.exosite.io/api:1/solution/XYZ/endpoint"
  end

  it "initializes" do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq("#{@baseURI}/")
  end

  context "lists" do
    it "same content_type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"application/json",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"application/json",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "missing headers" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"application/json",
               :script=>"response.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"application/json",
       :script=> "response.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "not default content_type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"text/csv",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id} image/png\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "mismatched content_type header" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"text/csv",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      expect(ret).to eq(body)
    end

    it "returns empty content type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :content_type=>"",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      body.first.merge!({:content_type=>'application/json'})
      expect(ret).to eq(body)
    end

    it "returns missing content type" do
      body = [{:id=>"9K0",
               :method=>"websocket",
               :path=>"/api/v1/bar",
               :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n\n",
      },
      {:id=>"B76",
       :method=>"websocket",
       :path=>"/api/v1/foo/{id}",
       :content_type=>"image/png",
       :script=> "--#ENDPOINT WEBSOCKET /api/v1/foo/{id}\nresponse.message = \"HI\"\n\n-- BOB WAS HERE\n",
      }]
      stub_request(:get, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.list()
      body.first.merge!({:content_type=>'application/json'})
      expect(ret).to eq(body)
    end

  end


  context "fetches" do
    it "fetches" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"application/json",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq(body[:script])
    end

    it "yields" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"application/json",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = nil
      @srv.fetch('9K0') do |sc|
        ret = sc
      end
      expect(ret).to eq(body[:script])
    end

    it "missing headers" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"application/json",
              :script=>"response.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n")
    end

    it "not default content_type" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq(body[:script])
    end

    it "missing content_type header" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n")
    end

    it "mismatched content_type header" do
      body = {:id=>"9K0",
              :method=>"websocket",
              :path=>"/api/v1/bar",
              :content_type=>"text/csv",
              :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar image/png\nresponse.message = \"HI\"\n",
      }
      stub_request(:get, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq("--#ENDPOINT WEBSOCKET /api/v1/bar text/csv\nresponse.message = \"HI\"\n")
    end
  end

  it "removes" do
    stub_request(:delete, "#{@baseURI}/9K0").
      with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                      'Content-Type'=>'application/json'}).
      to_return(body: "")

    ret = @srv.remove('9K0')
    expect(ret).to eq({})
  end

  context "uploads" do
    around(:example) do |ex|
      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close
        @tio_ = tio
        ex.run
      end
    end

    it "over old version" do
      stub_request(:put, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload(@tio_.path,
        MrMurano::Webservice::Endpoint::RouteItem.new(
          :id=>"9K0",
          :method=>"websocket",
          :path=>"/api/v1/bar",
          :content_type=>"application/json",
      ), true)
      expect(ret)
    end

    it "when nothing is there" do
      stub_request(:put, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 404)
      stub_request(:post, "#{@baseURI}/").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload(@tio_.path,
        MrMurano::Webservice::Endpoint::RouteItem.new(
          :id=>"9K0",
          :method=>"websocket",
          :path=>"/api/v1/bar",
          :content_type=>"application/json",
      ), false)
      expect(ret)
    end

    it "without an itemkey" do
      stub_request(:post, @baseURI).
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(body: "")

      ret = @srv.upload(@tio_.path,
        MrMurano::Webservice::Endpoint::RouteItem.new(
          :method=>"websocket",
          :path=>"/api/v1/bar",
          :content_type=>"application/json",
      ), false)
      expect(ret)
    end

    it "Handles others errors" do
      stub_request(:put, "#{@baseURI}/9K0").
        with(:headers=>{'Authorization'=>'token TTTTTTTTTT',
                        'Content-Type'=>'application/json'}).
                        to_return(status: 502, body: "{}")

      expect(@srv).to receive(:error).and_return(nil)
      ret = @srv.upload(@tio_.path,
        MrMurano::Webservice::Endpoint::RouteItem.new(
          :id=>"9K0",
          :method=>"websocket",
          :path=>"/api/v1/bar",
          :content_type=>"application/json",
      ), true)
      expect(ret)
    end
  end

  context "compares" do
    before(:example) do
      @iA = {:id=>"9K0",
             :method=>"websocket",
             :path=>"/api/v1/bar",
             :content_type=>"application/json",
             :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
             }
      @iB = {:id=>"9K0",
             :method=>"websocket",
             :path=>"/api/v1/bar",
             :content_type=>"application/json",
             :script=>"--#ENDPOINT WEBSOCKET /api/v1/bar\nresponse.message = \"HI\"\n",
             }
    end
    it "both have script" do
      ret = @srv.docmp(@iA, @iB)
      expect(ret).to eq(false)
    end

    it "iA is a local file" do
      Tempfile.open('foo') do |tio|
        tio << @iA[:script]
        tio.close
        iA = @iA.reject{|k,v| k == :script}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(iA, @iB)
        expect(ret).to eq(false)

        iB = @iB.dup
        iB[:script] = "BOB"
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(true)
      end
    end

    it "iB is a local file" do
      Tempfile.open('foo') do |tio|
        tio << @iB[:script]
        tio.close
        iB = @iB.reject{|k,v| k == :script}.merge({
          :local_path => Pathname.new(tio.path)
        })
        ret = @srv.docmp(@iA, iB)
        expect(ret).to eq(false)

        iA = @iB.dup
        iA[:script] = "BOB"
        ret = @srv.docmp(iA, iB)
        expect(ret).to eq(true)
      end
    end
  end

  context "Lookup functions" do
    it "gets local name" do
      ret = @srv.tolocalname({ :method=>'get', :path=>'one/two/three' }, nil)
      expect(ret).to eq('one-two-three.get.lua')
    end

    it "gets synckey" do
      ret = @srv.synckey({ :method=>'get', :path=>'one/two/three' })
      expect(ret).to eq("GET_one/two/three")
    end

    it "gets searchfor" do
      $cfg['endpoints.searchFor'] = %{a b c/**/d/*.bob}
      ret = @srv.searchFor
      expect(ret).to eq(["a", "b", "c/**/d/*.bob"])
    end

    it "gets ignoring" do
      $cfg['endpoints.ignoring'] = %{a b c/**/d/*.bob}
      ret = @srv.ignoring
      expect(ret).to eq(["a", "b", "c/**/d/*.bob"])
    end
  end

  context "to_remote_item" do
    it "reads one" do
      Tempfile.open("foo") do |tio|
        tio << %{--#ENDPOINT GET /one/two
        return request

        }.gsub(/^\s+/,'')
        tio.close

        ret = @srv.to_remote_item(nil, tio.path)
        e = {:method=>"GET",
             :path=>"/one/two",
             :content_type=>"application/json",
             :local_path=>Pathname.new(tio.path),
             :line=>0,
             :script=>"--#ENDPOINT GET /one/two\nreturn request\n",
             :line_end=>2
        }
        expect(ret).to eq([e])
      end
    end

    it "reads many" do
      Tempfile.open("foo") do |tio|
        tio << %{--#ENDPOINT GET /one/two
        return request
        --#ENDPOINT PUT /one/two
        return request

        --#ENDPOINT DELETE /three/two
        return request
        }.gsub(/^\s+/,'')
        tio.close

        ret = @srv.to_remote_item(nil, tio.path)

        expect(ret).to eq([
          {
            :method=>"GET",
            :path=>"/one/two",
            :content_type=>"application/json",
            :local_path=>Pathname.new(tio.path),
            :line=>0,
            :script=>"--#ENDPOINT GET /one/two\nreturn request\n",
            :line_end=>2
          },
          {
            :method=>"PUT",
            :path=>"/one/two",
            :content_type=>"application/json",
            :local_path=>Pathname.new(tio.path),
            :line=>2,
            :script=>"--#ENDPOINT PUT /one/two\nreturn request\n",
            :line_end=>4
          },
          {
            :method=>"DELETE",
            :path=>"/three/two",
            :content_type=>"application/json",
            :local_path=>Pathname.new(tio.path),
            :line=>4,
            :script=>"--#ENDPOINT DELETE /three/two\nreturn request\n",
            :line_end=>6
          }
        ])
      end
    end

    it "skips all when no header found" do
      Tempfile.open("foo") do |tio|
        tio << %{
        return request

        }.gsub(/^\s+/,'')
        tio.close

        ret = @srv.to_remote_item(nil, tio.path)
        expect(ret).to eq([])
      end
    end

    it "skips junk at begining" do
      Tempfile.open("foo") do |tio|
        tio << %{
        return flex
        --#ENDPOINT GET /one/two
        return request

        }.gsub(/^\s+/,'')
        tio.close

        ret = @srv.to_remote_item(nil, tio.path)
        e = {:method=>"GET",
             :path=>"/one/two",
             :content_type=>"application/json",
             :local_path=>Pathname.new(tio.path),
             :line=>1,
             :script=>"--#ENDPOINT GET /one/two\nreturn request\n",
             :line_end=>3
        }
        expect(ret).to eq([e])
      end
    end
  end

  context "Matching" do
    before(:example) do
      @an_item = {
        :method=>'get',
        :path=>'/api/read/stuff',
        :local_path=>Pathname.new('a/relative/path.lua'),
      }
    end
    context "method" do
      it "any path" do
        ret = @srv.match(@an_item, '#get#')
        expect(ret).to be true
        ret = @srv.match(@an_item, '#post#')
        expect(ret).to be false
      end
      it "exact path" do
        ret = @srv.match(@an_item, '#get#/api/read/stuff')
        expect(ret).to be true
        ret = @srv.match(@an_item, '#post#/api/read/stuff')
        expect(ret).to be false
      end
      it "path glob" do
        ret = @srv.match(@an_item, '#get#/api/*/stuff')
        expect(ret).to be true
        ret = @srv.match(@an_item, '#get#/**/stuff')
        expect(ret).to be true
      end
    end
    context "any method" do
      it "any path" do
        ret = @srv.match(@an_item, '##')
        expect(ret).to be true
      end
      it "exact path" do
        ret = @srv.match(@an_item, '##/api/read/stuff')
        expect(ret).to be true
        ret = @srv.match(@an_item, '##/api/do/stuff')
        expect(ret).to be false
      end
      it "path glob" do
        ret = @srv.match(@an_item, '##/api/*/stuff')
        expect(ret).to be true
        ret = @srv.match(@an_item, '##/**/stuff')
        expect(ret).to be true
      end
    end
  end

end
#  vim: set ai et sw=2 ts=2 :
