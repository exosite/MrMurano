# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'pathname'
require 'tempfile'
require 'MrMurano/version'
require 'MrMurano/ProjectFile'
require 'MrMurano/Solution-Services'
require '_workspace'

RSpec.describe MrMurano::Module do
  include_context 'WORKSPACE'
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['application.id'] = 'XYZ'

    @srv = MrMurano::Module.new
    allow(@srv).to receive(:token).and_return('TTTTTTTTTT')
  end

  it 'initializes' do
    uri = @srv.endpoint('/')
    expect(uri.to_s).to eq(
      'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/'
    )
  end

  it 'lists' do
    body = {
      items: [
        {
          id: '9K0',
          name: 'debug',
          alias: 'XYZ_debug',
          solution_id: 'XYZ',
          created_at: '2016-07-07T19:16:19.479Z',
          updated_at: '2016-09-12T13:26:55.868Z',
        },
      ],
      total: 1,
    }
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: body.to_json)

    ret = @srv.list
    expect(ret).to eq(body[:items])
  end

  context 'fetching' do
    it 'fetches' do
      body = {
        id: '9K0',
        name: 'debug',
        alias: 'XYZ_debug',
        solution_id: 'XYZ',
        created_at: '2016-07-07T19:16:19.479Z',
        updated_at: '2016-09-12T13:26:55.868Z',
        script: %{-- lua code is here
      function foo(bar)
        return bar + 1
      end
      },
      }
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/9K0'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq(body[:script])
    end

    it 'fetches with block' do
      body = {
        id: '9K0',
        name: 'debug',
        alias: 'XYZ_debug',
        solution_id: 'XYZ',
        created_at: '2016-07-07T19:16:19.479Z',
        updated_at: '2016-09-12T13:26:55.868Z',
        script: %{-- lua code is here
      function foo(bar)
        return bar + 1
      end
      },
      }
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/9K0'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: body.to_json)

      ret = nil
      @srv.fetch('9K0') { |sc| ret = sc }
      expect(ret).to eq(body[:script])
    end

    it 'Returns empty if script missing' do
      body = {
        id: '9K0',
        name: 'debug',
        alias: 'XYZ_debug',
        solution_id: 'XYZ',
        created_at: '2016-07-07T19:16:19.479Z',
        updated_at: '2016-09-12T13:26:55.868Z',
      }
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/9K0'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: body.to_json)

      ret = @srv.fetch('9K0')
      expect(ret).to eq('')
    end

    it 'Displays error if wrong result type' do
      stub_request(
        :get, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/9K0'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: "this isn't what we expected")

      saved = $stderr
      $stderr = StringIO.new
      ret = @srv.fetch('9K0')
      expect(ret).to eq('')
      expect($stderr.string).to start_with(
        %(\e[31m#{MrMurano::SolutionId::UNEXPECTED_TYPE_OR_ERROR_MSG})
      )
      $stderr = saved
    end
  end

  it 'removes' do
    stub_request(
      :delete, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/9K0'
    ).with(
      headers: {
        'Authorization' => 'token TTTTTTTTTT',
        'Content-Type' => 'application/json',
      }
    ).to_return(body: '')

    ret = @srv.remove('9K0')
    expect(ret).to eq({})
  end

  context 'uploads' do
    it 'over old version' do
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/XYZ_debug'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: '')

      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close

        ret = @srv.upload(
          tio.path,
          MrMurano::Module::ModuleItem.new(
            id: '9K0',
            name: 'debug',
            alias: 'XYZ_debug',
            solution_id: 'XYZ',
          )
        )
        expect(ret)
      end
    end

    it 'when nothing is there' do
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/XYZ_debug'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(status: 404)
      stub_request(
        :post, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: '')

      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close

        ret = @srv.upload(
          tio.path,
          MrMurano::Module::ModuleItem.new(
            id: '9K0',
            name: 'debug',
            alias: 'XYZ_debug',
            solution_id: 'XYZ',
          )
        )
        expect(ret)
      end
    end

    it 'shows other errors' do
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/XYZ_debug'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(status: 418, body: %({"teapot":true}))

      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close

        expect(@srv).to receive(:error).and_return(nil)
        ret = @srv.upload(
          tio.path,
          MrMurano::Module::ModuleItem.new(
            id: '9K0',
            name: 'debug',
            alias: 'XYZ_debug',
            solution_id: 'XYZ',
          )
        )
        expect(ret)
      end
    end

    it 'over old version; replacing cache miss' do
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/XYZ_debug'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: '')

      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close

        cache_file = $cfg.file_at(@srv.cache_file_name)
        FileUtils.touch(cache_file.to_path)
        ret = @srv.upload(
          tio.path,
          MrMurano::Module::ModuleItem.new(
            id: '9K0',
            name: 'debug',
            alias: 'XYZ_debug',
            solution_id: 'XYZ',
          )
        )
        expect(ret)
      end
    end

    it 'over old version; replacing cache hit' do
      stub_request(
        :put, 'https://bizapi.hosted.exosite.io/api:1/solution/XYZ/module/XYZ_debug'
      ).with(
        headers: {
          'Authorization' => 'token TTTTTTTTTT',
          'Content-Type' => 'application/json',
        }
      ).to_return(body: '')

      Tempfile.open('foo') do |tio|
        tio << %{-- lua code is here
          function foo(bar)
            return bar + 1
          end
        }
        tio.close

        cache_file = $cfg.file_at(@srv.cache_file_name)
        cache_file.open('w') do |cfio|
          cfio << {
            tio.path => {
              sha1: '6',
              updated_at: Time.now.getutc.to_datetime.iso8601(3),
            },
          }.to_yaml
        end
        ret = @srv.upload(
          tio.path,
          MrMurano::Module::ModuleItem.new(
            id: '9K0',
            name: 'debug',
            alias: 'XYZ_debug',
            solution_id: 'XYZ',
          )
        )
        expect(ret)
      end
    end
  end

  context 'compares' do
    before(:example) do
      @i_a = {
        id: '9K0',
        name: 'debug',
        alias: 'XYZ_debug',
        solution_id: 'XYZ',
        created_at: '2016-07-07T19:16:19.479Z',
        updated_at: '2016-09-12T13:26:55.868Z',
      }
      @i_b = {
        id: '9K0',
        name: 'debug',
        alias: 'XYZ_debug',
        solution_id: 'XYZ',
        created_at: '2016-07-07T19:16:19.479Z',
        updated_at: '2016-09-12T13:26:55.868Z',
      }
    end
    it 'both have updated_at' do
      ret = @srv.docmp(@i_a, @i_b)
      expect(ret).to eq(false)
    end

    context 'i_a is a local file' do
      it 'no cache_file' do
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          i_a = @i_a.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(i_a, @i_b)
          expect(ret).to eq(true)

          i_b = @i_b.merge(updated_at: Pathname.new(tio.path).mtime.getutc)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end

      it 'cache miss' do
        cache_file = $cfg.file_at(@srv.cache_file_name)
        FileUtils.touch(cache_file.to_path)
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          i_a = @i_a.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(i_a, @i_b)
          expect(ret).to eq(true)

          i_b = @i_b.merge(updated_at: Pathname.new(tio.path).mtime.getutc)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end

      it 'cache hit' do
        cache_file = $cfg.file_at(@srv.cache_file_name)
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          tio_mtime = Pathname.new(tio.path).mtime.getutc
          entry = {
            sha1: Digest::SHA1.file(tio.path).hexdigest,
            updated_at: tio_mtime.to_datetime.iso8601(3),
          }
          cache_file.open('w') do |io|
            cache = {}
            cache[tio.path] = entry
            io << cache.to_yaml
          end

          i_a = @i_a.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(i_a, @i_b)
          expect(ret).to eq(true)

          i_b = @i_b.merge(updated_at: tio_mtime)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end
    end

    context 'i_b is a local file' do
      it 'no cache_file' do
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          i_b = @i_b.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(@i_a, i_b)
          expect(ret).to eq(true)

          i_a = @i_a.merge(updated_at: Pathname.new(tio.path).mtime.getutc)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end

      it 'cache miss' do
        cache_file = $cfg.file_at(@srv.cache_file_name)
        FileUtils.touch(cache_file.to_path)
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          i_b = @i_b.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(@i_a, i_b)
          expect(ret).to eq(true)

          i_a = @i_a.merge(updated_at: Pathname.new(tio.path).mtime.getutc)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end

      it 'cache hit' do
        cache_file = $cfg.file_at(@srv.cache_file_name)
        Tempfile.open('foo') do |tio|
          tio << 'something'
          tio.close
          tio_mtime = Pathname.new(tio.path).mtime.getutc
          entry = {
            sha1: Digest::SHA1.file(tio.path).hexdigest,
            updated_at: tio_mtime.to_datetime.iso8601(3),
          }
          cache_file.open('w') do |io|
            cache = {}
            cache[tio.path] = entry
            io << cache.to_yaml
          end

          i_b = @i_b.reject do |k, _v|
            k == :updated_at
          end.merge(local_path: Pathname.new(tio.path))
          ret = @srv.docmp(@i_a, i_b)
          expect(ret).to eq(true)

          i_a = @i_a.merge(updated_at: tio_mtime)
          ret = @srv.docmp(i_a, i_b)
          expect(ret).to eq(false)
        end
      end
    end
  end

  context 'Lookup functions' do
    it 'gets local name' do
      ret = @srv.tolocalname({ name: 'bob' }, nil)
      expect(ret).to eq('bob.lua')
    end

    it 'gets synckey' do
      ret = @srv.synckey(name: 'device')
      expect(ret).to eq('device')
    end

    it 'gets searchfor' do
      $cfg['modules.searchFor'] = %(a b c/**/d/*.bob)
      ret = @srv.searchFor
      expect(ret).to eq(['a', 'b', 'c/**/d/*.bob'])
    end

    it 'gets ignoring' do
      $cfg['modules.ignoring'] = %(a b c/**/d/*.bob)
      ret = @srv.ignoring
      expect(ret).to eq(['a', 'b', 'c/**/d/*.bob'])
    end

    it 'raises on alias without name' do
      expect do
        @srv.mkname(MrMurano::Module::EventHandlerItem.new)
      end.to raise_error(NameError)
    end

    it 'raises on name without name' do
      expect do
        @srv.mkalias(MrMurano::Module::EventHandlerItem.new)
      end.to raise_error(NameError)
    end
  end

  context 'to_remote_item' do
    it 'reads one' do
      root = Pathname.new(@project_dir)
      path = Pathname.new(@project_dir) + 'test.lua'
      ret = @srv.to_remote_item(root, path)
      expect(ret).to eq(name: 'test')
    end
    it 'reads sub folder one' do
      root = Pathname.new(@project_dir)
      path = Pathname.new(@project_dir) + 'src/test.lua'
      ret = @srv.to_remote_item(root, path)
      expect(ret).to eq(name: 'src.test')
    end
  end
end

