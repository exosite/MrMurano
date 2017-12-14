# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'pathname'
require 'MrMurano/verbosing'
require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'
require '_workspace'

class TSUD
  include MrMurano::Verbose
  include MrMurano::SyncUpDown

  def initialize
    # 2017-07-03: See MrMurano::SolutionBase.state for the list of attrs.
    @api_id = 'XYZ'
    @valid_api_id = true
    @uriparts = []
    @solntype = 'application.id'
    @itemkey = :name
    @project_section = :routes
  end

  attr_reader :api_id

  def api_id?
    @valid_api_id
  end

  def fetch(id)
  end

  def self.description
    %(Time Series Database)
  end
end

RSpec::Matchers.define :pathname_globs do |glob|
  match do |pthnm|
    pthnm.fnmatch(glob)
  end
end

ITEM_UPDATED_AT = '2017-06-24T00:45:15.564Z'

RSpec.describe MrMurano::SyncUpDown do
  include_context 'WORKSPACE'
  before(:example) do
    MrMurano::SyncRoot.instance.reset
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load
    $project['routes.location'] = 'tsud'
    $project['routes.include'] = ['*.lua', '*/*.lua']
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['product.id'] = 'XYZ'
    $cfg['application.id'] = 'XYZ'
  end

  context 'status' do
    it 'warns with missing directory' do
      t = TSUD.new
      expect(t).to receive(:warning).once.with(/Skipping missing location.*/)
      ret = t.status
      expect(ret).to eq(
        toadd: [], todel: [], tomod: [], unchg: [], skipd: [], clash: []
      )
    end

    it 'finds nothing in empty directory' do
      FileUtils.mkpath(@project_dir + '/tsud')
      t = TSUD.new
      ret = t.status
      expect(ret).to eq(
        toadd: [], todel: [], tomod: [], unchg: [], skipd: [], clash: []
      )
    end

    it 'finds things there but not here' do
      FileUtils.mkpath(@project_dir + '/tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return(
        [
          { name: 1 },
          { name: 2 },
          { name: 3 },
        ]
      )
      ret = t.status
      expect(ret).to eq(
        toadd: [],
        todel: [
          {
            name: 1,
            synckey: 1,
            synctype: TSUD.description,
          },
          {
            name: 2,
            synckey: 2,
            synctype: TSUD.description,
          },
          {
            name: 3,
            synckey: 3,
            synctype: TSUD.description,
          },
        ],
        tomod: [],
        unchg: [],
        skipd: [],
        clash: []
      )
    end

    it 'finds things there but not here; asdown' do
      FileUtils.mkpath(@project_dir + '/tsud')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return(
        [
          { name: 1 },
          { name: 2 },
          { name: 3 },
        ]
      )
      ret = t.status(asdown: true)
      expect(ret).to eq(
        todel: [],
        toadd: [
          { name: 1, synckey: 1, synctype: TSUD.description },
          { name: 2, synckey: 2, synctype: TSUD.description },
          { name: 3, synckey: 3, synctype: TSUD.description },
        ],
        tomod: [],
        unchg: [],
        skipd: [],
        clash: []
      )
    end

    it 'finds things here but not there' do
      FileUtils.mkpath(@project_dir + '/tsud')
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:to_remote_item).and_return(
        { name: 'one.lua' },
        name: 'two.lua',
      )
      ret = t.status
      expect(ret).to match(
        toadd: [
          {
            name: 'one.lua',
            synckey: 'one.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two.lua',
            synckey: 'two.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
        ],
        todel: [],
        tomod: [],
        unchg: [],
        skipd: [],
        clash: []
      )
    end

    it 'finds things here and there' do
      FileUtils.mkpath(@project_dir + '/tsud')
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return(
        [
          { name: 'one.lua' },
          { name: 'two.lua' },
        ]
      )
      expect(t).to receive(:to_remote_item).and_return(
        { name: 'one.lua' },
        name: 'two.lua',
      )
      ret = t.status
      expect(ret).to match(
        tomod: [
          {
            name: 'one.lua',
            synckey: 'one.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two.lua',
            synckey: 'two.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
        ],
        todel: [],
        toadd: [],
        unchg: [],
        skipd: [],
        clash: []
      )
    end
    it "finds things here and there; but they're the same" do
      FileUtils.mkpath(@project_dir + '/tsud')
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return(
        [
          { name: 'one.lua' },
          { name: 'two.lua' },
        ]
      )
      expect(t).to receive(:to_remote_item).and_return(
        { name: 'one.lua' },
        name: 'two.lua',
      )
      expect(t).to receive(:docmp).twice.and_return(false)
      ret = t.status
      expect(ret).to match(
        unchg: [
          {
            name: 'one.lua',
            synckey: 'one.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two.lua',
            synckey: 'two.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
          },
        ],
        todel: [],
        toadd: [],
        tomod: [],
        skipd: [],
        clash: []
      )
    end

    it 'calls diff' do
      FileUtils.mkpath(@project_dir + '/tsud')
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      t = TSUD.new
      expect(t).to receive(:list).once.and_return([
                                                    { name: 'one.lua' },
                                                  ])
      expect(t).to receive(:to_remote_item).and_return(
        name: 'one.lua'
      )
      expect(t).to receive(:dodiff).once.and_return('diffed output')
      ret = t.status(diff: true)
      expect(ret).to match(
        tomod: [
          {
            name: 'one.lua',
            synckey: 'one.lua',
            synctype: TSUD.description,
            local_path: an_instance_of(Pathname),
            diff: 'diffed output',
          },
        ],
        todel: [],
        toadd: [],
        unchg: [],
        skipd: [],
        clash: []
      )
    end

    context 'Filtering' do
      before(:example) do
        FileUtils.mkpath(@project_dir + '/tsud/ga')
        FileUtils.mkpath(@project_dir + '/tsud/gb')
        FileUtils.touch(@project_dir + '/tsud/one.lua')     # tomod
        FileUtils.touch(@project_dir + '/tsud/ga/two.lua')  # tomod
        FileUtils.touch(@project_dir + '/tsud/three.lua')   # unchg
        FileUtils.touch(@project_dir + '/tsud/gb/four.lua') # unchg
        FileUtils.touch(@project_dir + '/tsud/five.lua')    # toadd
        FileUtils.touch(@project_dir + '/tsud/ga/six.lua')  # toadd
        @t = TSUD.new
        expect(@t).to receive(:list).once.and_return(
          [
            MrMurano::SyncUpDown::Item.new(name: 'eight.lua', updated_at: ITEM_UPDATED_AT), # todel
            MrMurano::SyncUpDown::Item.new(name: 'four.lua', updated_at: ITEM_UPDATED_AT),  # unchg
            MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT),   # tomod
            MrMurano::SyncUpDown::Item.new(name: 'seven.lua', updated_at: ITEM_UPDATED_AT), # todel
            MrMurano::SyncUpDown::Item.new(name: 'three.lua', updated_at: ITEM_UPDATED_AT), # unchg
            MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT),   # tomod
          ]
        )
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/one.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT))
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/two.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT))
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/three.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'three.lua', updated_at: ITEM_UPDATED_AT))
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/four.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'four.lua', updated_at: ITEM_UPDATED_AT))
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/five.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'five.lua', updated_at: ITEM_UPDATED_AT))
        expect(@t).to receive(:to_remote_item)
          .with(anything, pathname_globs('**/six.lua'))
          .and_return(MrMurano::SyncUpDown::Item.new(name: 'six.lua', updated_at: ITEM_UPDATED_AT))

        expect(@t).to receive(:docmp).with(have_attributes(name: 'one.lua'), anything).and_return(true)
        expect(@t).to receive(:docmp).with(have_attributes(name: 'two.lua'), anything).and_return(true)
        expect(@t).to receive(:docmp).with(have_attributes(name: 'three.lua'), anything).and_return(false)
        expect(@t).to receive(:docmp).with(have_attributes(name: 'four.lua'), anything).and_return(false)
      end

      it 'Returns all with no filter' do
        ret = @t.status
        expect(ret).to match(
          unchg: [
            have_attributes(
              name: 'four.lua',
              synckey: 'four.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/four.lua')
            ),
            have_attributes(
              name: 'three.lua',
              synckey: 'three.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/three.lua')
            ),
          ],
          toadd: [
            have_attributes(
              name: 'five.lua',
              synckey: 'five.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/five.lua')
            ),
            have_attributes(
              name: 'six.lua',
              synckey: 'six.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/six.lua')
            ),
          ],
          todel: [
            have_attributes(
              name: 'eight.lua',
              synckey: 'eight.lua',
              synctype: TSUD.description
            ),
            have_attributes(
              name: 'seven.lua',
              synckey: 'seven.lua',
              synctype: TSUD.description
            ),
          ],
          tomod: [
            have_attributes(
              name: 'one.lua',
              synckey: 'one.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/one.lua')
            ),
            have_attributes(
              name: 'two.lua',
              synckey: 'two.lua',
              synctype: TSUD.description,
              local_path: pathname_globs('**/two.lua')
            ),
          ],
          skipd: [],
          clash: []
        )
      end

      it 'Finds local path globs' do
        ret = @t.status({}, ['**/ga/*.lua'])
        expect(ret).to match(
          unchg: [],
          toadd: [
            have_attributes(
              name: 'six.lua',
              synckey: 'six.lua',
              synctype: TSUD.description,
              local_path: an_instance_of(Pathname)
            ),
          ],
          todel: [],
          tomod: [
            have_attributes(
              name: 'two.lua',
              synckey: 'two.lua',
              synctype: TSUD.description,
              local_path: an_instance_of(Pathname)
            ),
          ],
          skipd: [],
          clash: []
        )
      end

      it 'Finds nothing with specific matcher' do
        ret = @t.status({}, ['#foo'])
        expect(ret).to match(
          unchg: [],
          toadd: [],
          todel: [],
          tomod: [],
          skipd: [],
          clash: []
        )
      end

      it 'gets all the details' do
        ret = @t.status(unselected: true)
        expect(ret).to match(
          unchg: [
            have_attributes(
              name: 'four.lua',
              synckey: 'four.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/four.lua')
            ),
            have_attributes(
              name: 'three.lua',
              synckey: 'three.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/three.lua')
            ),
          ],
          toadd: [
            have_attributes(
              name: 'five.lua',
              synckey: 'five.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/five.lua')
            ),
            have_attributes(
              name: 'six.lua',
              synckey: 'six.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/six.lua')
            ),
          ],
          todel: [
            have_attributes(
              name: 'eight.lua',
              selected: true,
              synckey: 'eight.lua',
              synctype: TSUD.description,
            ),
            have_attributes(
              name: 'seven.lua',
              selected: true,
              synckey: 'seven.lua',
              synctype: TSUD.description,
            ),
          ],
          tomod: [
            have_attributes(
              name: 'one.lua',
              synckey: 'one.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/one.lua')
            ),
            have_attributes(
              name: 'two.lua',
              synckey: 'two.lua',
              synctype: TSUD.description,
              selected: true,
              local_path: pathname_globs('**/two.lua')
            ),
          ],
          skipd: [],
          clash: []
        )
      end
    end
  end

  context 'localitems' do
    before(:example) do
      FileUtils.mkpath('tsud')
      FileUtils.touch('tsud/one.lua')
      FileUtils.touch('tsud/two.lua')
      @t = TSUD.new
    end
    it 'finds local items' do
      expect(@t).to receive(:to_remote_item).and_return(
        { name: 'one.lua' },
        name: 'two.lua',
      )
      ret = @t.localitems(Pathname.new(@project_dir + '/tsud').realpath)
      expect(ret).to match(
        [
          {
            name: 'one.lua',
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two.lua',
            local_path: an_instance_of(Pathname),
          },
        ]
      )
    end

    it 'takes an array from to_remote_item' do
      expect(@t).to receive(:to_remote_item).and_return(
        [
          { name: 'one:1' },
          { name: 'one:2' },
        ],
        [
          { name: 'two:1' },
          { name: 'two:2' },
        ],
      )
      ret = @t.localitems(Pathname.new(@project_dir + '/tsud').realpath)
      expect(ret).to match(
        [
          {
            name: 'one:1',
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'one:2',
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two:1',
            local_path: an_instance_of(Pathname),
          },
          {
            name: 'two:2',
            local_path: an_instance_of(Pathname),
          },
        ]
      )
    end
  end

  context 'download' do
    it 'defaults to :id if @itemkey missing' do
      FileUtils.mkpath(@project_dir + '/tsud')
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      lp = Pathname.new(@project_dir + '/tsud/one.lua').realpath
      t = TSUD.new
      expect(t).to receive(:fetch).once.with(1).and_yield('foo')
      t.download(lp, id: 1, updated_at: ITEM_UPDATED_AT)
    end
  end

  context 'doing diffs' do
    before(:example) do
      FileUtils.mkpath(@project_dir + '/tsud')
      @t = TSUD.new
      @scpt = Pathname.new(@project_dir + '/tsud/one.lua')
      @scpt.open('w') { |io| io << %(-- fake lua\nreturn 0\n) }
      @scpt = @scpt.realpath
    end

    it 'nothing when same.' do
      expect(@t).to receive(:fetch).and_yield(%(-- fake lua\nreturn 0\n))
      ret = @t.dodiff(
        {
          name: 'one.lua',
          local_path: @scpt,
          updated_at: ITEM_UPDATED_AT,
        },
        nil
      )
      if Gem.win_platform?
        expect(ret).to match(/FC: no differences encountered/)
      else
        expect(ret).to eq('')
      end
    end

    it 'something when different.' do
      expect(@t).to receive(:fetch).and_yield(%(-- fake lua\nreturn 2\n))
      ret = @t.dodiff(
        {
          name: 'one.lua',
          local_path: @scpt,
          updated_at: ITEM_UPDATED_AT,
        },
        nil
      )
      expect(ret).not_to eq('')
    end

    it 'uses script in item' do
      script = %(-- fake lua\nreturn 2\n)
      expect(@t).to receive(:fetch).and_yield(script)
      ret = @t.dodiff(
        {
          name: 'one.lua',
          local_path: @scpt,
          script: script,
          updated_at: ITEM_UPDATED_AT,
        },
        nil
      )
      if Gem.win_platform?
        expect(ret).to match(/FC: no differences encountered/)
      else
        expect(ret).to eq('')
      end
    end
  end

  context 'syncup' do
    before(:example) do
      FileUtils.mkpath(@project_dir + '/tsud')
      @t = TSUD.new
    end

    it 'removes' do
      expect(@t).to receive(:list).once.and_return(
        [
          { name: 1 },
          { name: 2 },
          { name: 3 },
        ]
      )
      expect(@t).to receive(:remove).exactly(3).times
      @t.syncup(delete: true)
    end

    it 'creates' do
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')

      expect(@t).to receive(:upload).twice
                                    .with(kind_of(Pathname), kind_of(MrMurano::SyncUpDown::Item), false)
      @t.syncup(create: true)
    end

    it 'updates' do
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')
      expect(@t).to receive(:list).once.and_return(
        [
          MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT),
          MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT),
        ]
      )

      expect(@t).to receive(:upload).twice.with(
        kind_of(Pathname), kind_of(MrMurano::SyncUpDown::Item), true
      )
      expect(@t).to receive(:to_remote_item).and_return(
        { name: 'one.lua' },
        name: 'two.lua',
      )
      @t.syncup(update: true)
    end
  end

  context 'syncdown' do
    before(:example) do
      FileUtils.mkpath(@project_dir + '/tsud')
      @t = TSUD.new
    end

    it 'removes' do
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')

      @t.syncdown(delete: true)
      expect(FileTest.exist?(@project_dir + '/tsud/one.lua')).to be false
      expect(FileTest.exist?(@project_dir + '/tsud/two.lua')).to be false
    end

    it 'creates' do
      expect(@t).to receive(:list).once.and_return(
        [
          MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT),
          MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT),
        ]
      )

      expect(@t).to receive(:fetch).twice.and_yield("--foo\n")
      @t.syncdown(create: true)
      expect(FileTest.exist?(@project_dir + '/tsud/one.lua')).to be true
      expect(FileTest.exist?(@project_dir + '/tsud/two.lua')).to be true
    end

    it 'updates' do
      FileUtils.touch(@project_dir + '/tsud/one.lua')
      FileUtils.touch(@project_dir + '/tsud/two.lua')
      expect(@t).to receive(:list).once.and_return(
        [
          MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT),
          MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT),
        ]
      )

      expect(@t).to receive(:fetch).twice.and_yield("--foo\n")
      expect(@t).to receive(:to_remote_item).and_return(
        MrMurano::SyncUpDown::Item.new(name: 'one.lua', updated_at: ITEM_UPDATED_AT),
        MrMurano::SyncUpDown::Item.new(name: 'two.lua', updated_at: ITEM_UPDATED_AT)
      )
      @t.syncdown(update: true)
      expect(FileTest.exist?(@project_dir + '/tsud/one.lua')).to be true
      expect(FileTest.exist?(@project_dir + '/tsud/two.lua')).to be true
    end
  end

#  context "bundles" do
#    before(:example) do
#      FileUtils.mkpath(@project_dir + '/tsud')
#      FileUtils.mkpath(@project_dir + '/bundles/mybun/tsud')
#      @t = TSUD.new
#    end
#
#    it "finds items in bundles." do
#      FileUtils.touch(@project_dir + '/tsud/one.lua')
#      FileUtils.touch(@project_dir + '/bundles/mybun/tsud/two.lua')
#
#      expect(@t).to receive(:to_remote_item).and_return(
#        {name: 'two.lua'},{name: 'one.lua'}
#      )
#      ret = @t.locallist
#      expect(ret).to match([
#        {name: 'two.lua',
#         bundled: true,
#         local_path: an_instance_of(Pathname)},
#        {name: 'one.lua',
#         local_path: an_instance_of(Pathname)},
#      ])
#    end
#
#    it "Doesn't download a bundled item" do
#      FileUtils.touch(@project_dir + '/tsud/one.lua')
#      lp = Pathname.new(@project_dir + '/tsud/one.lua').realpath
#
#      expect(@t).to receive(:warning).once.with(/Not downloading into bundled item.*/)
#
#      @t.download(lp, {bundled: true, name: 'one.lua'})
#    end
#  end
end

