# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'json'
require 'open3'
require 'vine'
require 'cmd_common'

RSpec.describe 'murano setting', :cmd, :needs_password do
  include_context 'CI_CMD'

  before(:example) do
    @product_name = rname('settingtest')
    out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @product_name, '--save'))
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)
  end
  after(:example) do
    out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'reads Webservice.cors' do
    out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
    expect { JSON.parse(out) }.to_not raise_error
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  it 'reads Webservice.cors to a file' do
    out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-o', 'testout', '-c', 'outformat=json'))
    expect(err).to eq('')
    expect(out).to eq('')
    expect(status.exitstatus).to eq(0)
    expect(File.exist?('testout')).to be true
  end

  context 'Writes (using Webservice.cors)' do
    before(:example) do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
      expect { @json_before = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
    end
    # {'origin'=>true,
    # 'methods'=>['HEAD', 'GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    # 'headers'=>['Content-Type', 'Cookie', 'Authorization'],
    # 'credentials'=>true}

    context 'a bool value' do
      it 'Yes' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'Yes'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = true
        expect(json_after).to match(@json_before)
      end

      it 'true' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'true'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = true
        expect(json_after).to match(@json_before)
      end

      it 'on' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'on'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = true
        expect(json_after).to match(@json_before)
      end

      it '1' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', '1'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = true
        expect(json_after).to match(@json_before)
      end

      it 'bob' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'bob'))
        expect(err).to eq("\e[31mValue \"bob\" is not a bool type!\e[0m\n")
        expect(out).to eq('')
        expect(status.exitstatus).to eq(2)
      end

      it 'No' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'No'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = false
        expect(json_after).to match(@json_before)
      end

      it 'false' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'false'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = false
        expect(json_after).to match(@json_before)
      end

      it 'off' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', 'Off'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = false
        expect(json_after).to match(@json_before)
      end

      it '0' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool', '0'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = false
        expect(json_after).to match(@json_before)
      end

      it 'on STDIN' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'origin', '--bool'), stdin_data: 'true')
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before['origin'] = true
        expect(json_after).to match(@json_before)
      end
    end

    it 'a json array blob' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'headers', '--json', '["fidget", "forgotten", "tokens"]'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['headers'] = %w[fidget forgotten tokens]
      expect(json_after).to match(@json_before)
    end

    it 'a json array blob with STDIN' do
      out, err, status = Open3.capture3(
        capcmd(
          'murano',
          'setting',
          'write',
          'Webservice.cors',
          'headers',
          '--json'
        ),
        stdin_data: '["fidget", "forgotten", "tokens"]'
      )
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['headers'] = %w[fidget forgotten tokens]
      expect(json_after).to match(@json_before)
    end

    it 'an array' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'headers', '--array', 'fidget', 'forgotten', 'tokens'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['headers'] = %w[fidget forgotten tokens]
      expect(json_after).to match(@json_before)
    end

    it 'appends an array' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Webservice.cors', 'headers', '--array', '--append', 'fidget', 'forgotten', 'tokens'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Webservice.cors', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['headers'] = @json_before['headers'] + %w[fidget forgotten tokens]
      expect(json_after).to match(@json_before)
    end
  end
end

