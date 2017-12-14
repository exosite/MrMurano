# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'highline/import'
require 'MrMurano/hash'
require 'MrMurano/version'
require 'MrMurano/verbosing'
require 'MrMurano/Config'
require '_workspace'

class VTst
  include MrMurano::Verbose
  def initialize
    @token = nil
  end
end
RSpec.describe MrMurano::Verbose do
  include_context 'WORKSPACE'

  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
    @tst = VTst.new
  end

  it 'verboses' do
    $cfg['tool.verbose'] = true
    expect($terminal).to receive(:say).with('hello').once
    @tst.verbose 'hello'
  end

  it 'is quiet' do
    expect($terminal).to_not receive(:say)
    @tst.verbose 'hello'
  end

  it 'debugs' do
    $cfg['tool.debug'] = true
    expect($terminal).to receive(:say).with('hello').once
    @tst.debug 'hello'
  end

  it 'warns' do
    expect($stderr).to receive(:puts).with("\e[33mhello\e[0m").once
    @tst.warning 'hello'
  end

  it 'errors' do
    expect($stderr).to receive(:puts).with("\e[31mhello\e[0m").once
    @tst.error 'hello'
  end

  context 'tabularize' do
    context 'generating CSV' do
      before(:example) do
        $cfg['tool.outformat'] = 'csv'
      end

      it 'takes Array' do
        $stdout = StringIO.new

        @tst.tabularize([[1, 2, 3, 4, 5, 6, 7], [10, 20, 30, 40, 50, 60, 70]])

        expect($stdout.string).to eq("1,2,3,4,5,6,7\n10,20,30,40,50,60,70\n")
      end

      it 'ducks to_a' do
        $stdout = StringIO.new

        class DuckToATest
          def to_a
            [[12], [13]]
          end
        end
        @tst.tabularize(DuckToATest.new)

        expect($stdout.string).to eq("12\n13\n")
      end

      it 'ducks each' do
        $stdout = StringIO.new

        class DuckEachTest
          def each
            yield [22]
            yield [44]
          end
        end
        @tst.tabularize(DuckEachTest.new)

        expect($stdout.string).to eq("22\n44\n")
      end

      context 'takes Hash' do
        before(:example) do
          @hsh = {
            headers: %i[one two three],
            title: 'Test output',
            rows: [[1, 2, 3], [10, 20, 30]],
          }
          $stdout = StringIO.new
        end
        it 'has all' do
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq("one,two,three\n1,2,3\n10,20,30\n")
        end

        it 'is empty' do
          @tst.tabularize({})
          expect($stdout.string).to eq("\n")
        end

        it 'no headers' do
          @hsh.delete :headers
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq("1,2,3\n10,20,30\n")
        end

        it 'no title' do
          @hsh.delete :title
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq("one,two,three\n1,2,3\n10,20,30\n")
        end

        it 'no rows' do
          @hsh.delete :rows
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq("one,two,three\n\n")
        end
      end

      it "errors if it can't" do
        $stdout = StringIO.new
        # 2017-07-03: [lb] converted to class func.
        #expect(@tst).to receive(:error).with(MrMurano::Verbose::TABULARIZE_DATA_FORMAT_ERROR).once
        expect(MrMurano::Verbose).to receive(:error).with(MrMurano::Verbose::TABULARIZE_DATA_FORMAT_ERROR).once
        @tst.tabularize(12)
      end

      it 'takes Array, to custom stream' do
        $stdout = StringIO.new
        outer = StringIO.new

        @tst.tabularize([[1, 2, 3, 4, 5, 6, 7], [10, 20, 30, 40, 50, 60, 70]], outer)

        expect(outer.string).to eq("1,2,3,4,5,6,7\n10,20,30,40,50,60,70\n")
        expect($stdout.string).to eq('')
      end
    end

    context 'generating a table' do
      it 'takes Array' do
        $stdout = StringIO.new
        @tst.tabularize([[1, 2, 3, 4, 5, 6, 7], [10, 20, 30, 40, 50, 60, 70]])
        expect($stdout.string).to eq(
          %(+----+----+----+----+----+----+----+
            | 1  | 2  | 3  | 4  | 5  | 6  | 7  |
            | 10 | 20 | 30 | 40 | 50 | 60 | 70 |
            +----+----+----+----+----+----+----+
            ).gsub(/^\s+/, '')
        )
      end

      context 'takes Hash' do
        before(:example) do
          @hsh = {
            headers: %i[one two three],
            title: 'Test output',
            rows: [[1, 2, 3], [10, 20, 30]],
          }
          $stdout = StringIO.new
        end
        it 'has all' do
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq(
            %(+-----+-----+-------+
              |    Test output    |
              +-----+-----+-------+
              | one | two | three |
              +-----+-----+-------+
              | 1   | 2   | 3     |
              | 10  | 20  | 30    |
              +-----+-----+-------+
              ).gsub(/^\s+/, '')
          )
        end

        it 'is empty' do
          @tst.tabularize({})
          expect($stdout.string).to eq("++\n++\n")
        end

        it 'no headers' do
          @hsh.delete :headers
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq(
            %(+----+----+----+
              | Test output  |
              +----+----+----+
              | 1  | 2  | 3  |
              | 10 | 20 | 30 |
              +----+----+----+
              ).gsub(/^\s+/, '')
          )
        end

        it 'no title' do
          @hsh.delete :title
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq(
            %(+-----+-----+-------+
              | one | two | three |
              +-----+-----+-------+
              | 1   | 2   | 3     |
              | 10  | 20  | 30    |
              +-----+-----+-------+
              ).gsub(/^\s+/, '')
          )
        end

        it 'no rows' do
          @hsh.delete :rows
          @tst.tabularize(@hsh)
          expect($stdout.string).to eq(
            %(+-----+-----+-------+
            |    Test output    |
            +-----+-----+-------+
            | one | two | three |
            +-----+-----+-------+
            +-----+-----+-------+
            ).gsub(/^\s+/, '')
          )
        end
      end
    end
  end

  context 'outf' do
    before(:example) do
      @data = {
        one: 'three',
        two: [{ one: 3 }, { one: 4 }],
      }
      $stdout = StringIO.new
    end

    it 'outputs yaml' do
      $cfg['tool.outformat'] = 'yaml'
      @tst.outf(@data)
      expect($stdout.string).to eq("---\none: three\ntwo:\n- one: 3\n- one: 4\n")
    end

    it 'outputs json' do
      $cfg['tool.outformat'] = 'json'
      @tst.outf(@data)
      expect($stdout.string).to eq("{\"one\":\"three\",\"two\":[{\"one\":3},{\"one\":4}]}\n")
    end

    it 'outputs ruby' do
      $cfg['tool.outformat'] = 'pp'
      @tst.outf(@data)
      expect($stdout.string).to eq("{:one=>\"three\", :two=>[{:one=>3}, {:one=>4}]}\n")
    end

    it 'outputs as String' do
      @tst.outf(@data)
      expect($stdout.string).to eq("{:one=>\"three\", :two=>[{:one=>3}, {:one=>4}]}\n")
    end

    it 'outputs as Array' do
      @tst.outf([1, 2, 3, 4, 5])
      expect($stdout.string).to eq("1\n2\n3\n4\n5\n")
    end

    it 'returns to block' do
      @tst.outf(@data) do |_dd, ios|
        ios.puts 'pop'
      end
      expect($stdout.string).to eq("pop\n")
    end
  end
end

