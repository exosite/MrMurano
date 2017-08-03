# Last Modified: 2017.07.31 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require 'MrMurano/SyncRoot'
require 'MrMurano/SyncUpDown'
require '_workspace'

RSpec.describe MrMurano::SyncRoot do
  include_context "WORKSPACE"

  after(:example) do
    MrMurano::SyncRoot.instance.reset
  end

  before(:example) do
    MrMurano::SyncRoot.instance.reset # also creates @@syncset
    # Weird/2017-07-31: I [lb] must[ve changed something, because this
    # block being called twice, which is generating a warning:
    #   /exo/clients/exosite/MuranoCLIs/MuranoCLI+landonb/spec/SyncRoot_spec.rb:30:
    #       warning: method redefined; discarding old description
    #   /exo/clients/exosite/MuranoCLIs/MuranoCLI+landonb/spec/SyncRoot_spec.rb:30:
    #       warning: previous definition of description was here
    if !defined?(User)
      class User
        def self.description
          %(describe user)
        end
      end
    end
    if !defined?(Role)
      class Role
        def self.description
          %(describe role)
        end
      end
    end
    MrMurano::SyncRoot.instance.add('user', User, 'U', true)
    MrMurano::SyncRoot.instance.add('role', Role, 'R', false)

    # This must happen after all syncables have been added.
    $cfg = MrMurano::Config.new
    $cfg.load
    $project = MrMurano::ProjectFile.new
    $project.load

    @options = {}
    @options.define_singleton_method(:method_missing) do |mid,*args|
      if mid.to_s.match(/^(.+)=$/) then
        self[$1.to_sym] = args.first
      else
        self[mid]
      end
    end
  end

  it "has defaults" do
    ret = MrMurano::SyncRoot.instance.bydefault
    expect(ret).to eq(['user'])
  end

  it "iterates on each" do
    ret=[]
    MrMurano::SyncRoot.instance.each { |a, _b, _c, _d| ret << a }
    expect(ret).to eq(["user", "role"])
  end

  it "iterates only on selected" do
    @options.role = true
    ret=[]
    MrMurano::SyncRoot.instance.each_filtered(@options) { |a, _b, _c, _d| ret << a }
    expect(ret).to eq(["role"])
  end

  it "selects all" do
    @options.all = true
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:all=>true, :user=>true, :role=>true})
  end

  it "selects defaults when none" do
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:user=>true})
  end

  it "selects custom defaults when none" do
    $cfg['sync.bydefault'] = 'role'
    MrMurano::SyncRoot.instance.check_same(@options)
    expect(@options).to eq({:role=>true})
  end

  it "builds option params" do
    ret=[]
    MrMurano::SyncRoot.instance.each_option do |s, l, d|
      ret << [s, l, d]
    end
    expect(ret).to eq([["-u", "--[no-]user", "describe user"], ["-r", "--[no-]role", "describe role"]])
  end
end

