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
    out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
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

  context 'Writes (using Device2.identity_format)' do
    before(:example) do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
      expect { @json_before = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
    end
    # {'prefix'=>'', 'type'=>'opaque', 'options'=>{'casing'=>'mixed', 'length'=>0}}

    it 'a string value' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'prefix', 'fidget'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['prefix'] = 'fidget'
      expect(json_after).to match(@json_before)
    end

    it 'a forced string value' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'prefix', '--string', 'fidget'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['prefix'] = 'fidget'
      expect(json_after).to match(@json_before)
    end

    it 'a forced string value on STDIN' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'prefix', '--string'), stdin_data: 'fidget')
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['prefix'] = 'fidget'
      expect(json_after).to match(@json_before)
    end

# This may not be testable in integration. (since it does things that get filtered out)
    it 'all intermediate keys' #do
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'one.two.three', 'fidget'))
#      expect(err).to eq('')
#      expect(out).to eq('')
#      expect(status.exitstatus).to eq(0)
#
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
#      json_after = nil
#      expect { json_after = JSON.parse(out) }.to_not raise_error
#      expect(err).to eq('')
#      expect(status.exitstatus).to eq(0)
#      @json_before.set('one.two.three', 'figdet')
#      expect(json_after).to match(@json_before)
#    end

    context 'a number value' do
      it 'integer 12' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options.length', '--num', '12'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before.set('options.length', 12)
        expect(json_after).to match(@json_before)
      end

      it 'float 12.67' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options.length', '--num', '12.67'))
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before.set('options.length', 12.67)
        expect(json_after).to match(@json_before)
      end

      it 'fiftyHalf' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options.length', '--num', 'fiftyHalf'))
        expect(err).to eq("\e[31mValue \"fiftyHalf\" is not a number\e[0m\n")
        expect(out).to eq('')
        expect(status.exitstatus).to eq(2)
      end

      it 'on STDIN' do
        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options.length', '--num'), stdin_data: '12')
        expect(err).to eq('')
        expect(out).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
        json_after = nil
        expect { json_after = JSON.parse(out) }.to_not raise_error
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
        @json_before.set('options.length', 12)
        expect(json_after).to match(@json_before)
      end
    end

    it 'a json object blob' #do
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'type', 'base16'))
#      expect(err).to eq('')
#      expect(out).to eq('')
#      expect(status.exitstatus).to eq(0)
#
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options', '--json', "{'casing': 'lower', 'length': 0}"))
#      expect(err).to eq('')
#      expect(out).to eq('')
#      expect(status.exitstatus).to eq(0)
#
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
#      json_after = nil
#      expect { json_after = JSON.parse(out) }.to_not raise_error
#      expect(err).to eq('')
#      expect(status.exitstatus).to eq(0)
#      @json_before['type'] = 'base16'
#      @json_before['options'] = {'casing'=>'lower', 'length'=>0}
#      expect(json_after).to match(@json_before)
#    end

    it 'a json object blob with stdin'

# This may not be testable in integration.
    it 'a dictionary' #do
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', 'options', '--dict', 'casing', 'lower'))
#      expect(err).to eq('')
#      expect(out).to eq('')
#      expect(status.exitstatus).to eq(0)
#
#      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
#      json_after = nil
#      expect { json_after = JSON.parse(out) }.to_not raise_error
#      expect(err).to eq('')
#      expect(status.exitstatus).to eq(0)
#      @json_before['options'] = {'casing'=>'lower', 'length'=>0}
#      expect(json_after).to match(@json_before)
#    end

    it 'merges into a dictionary' do
      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'write', 'Device2.identity_format', '.', '--dict', '--merge', 'prefix', 'tix', 'type', 'base10'))
      expect(err).to eq('')
      expect(out).to eq('')
      expect(status.exitstatus).to eq(0)

      out, err, status = Open3.capture3(capcmd('murano', 'setting', 'read', 'Device2.identity_format', '-c', 'outformat=json'))
      json_after = nil
      expect { json_after = JSON.parse(out) }.to_not raise_error
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)
      @json_before['prefix'] = 'tix'
      @json_before['type'] = 'base10'
      expect(json_after).to match(@json_before)
    end
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
  end
end

