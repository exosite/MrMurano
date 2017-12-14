# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'tempfile'
require 'MrMurano/version'
require 'MrMurano/Account'
require '_workspace'

RSpec.describe MrMurano::Passwords, '#pwd' do
  # Weird: This tests works on its own without the 'WORKSPACE',
  # but when run with other tests, it fails. (2017-07-05: I think
  # I just added the $cfg lines, because MrMurano::Passwords
  # expects $cfg to be loaded... [lb].)
  include_context 'WORKSPACE'

  before(:example) do
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load

    @saved_pwd = ENV['MURANO_PASSWORD']
    ENV['MURANO_PASSWORD'] = nil
  end
  after(:example) do
    ENV['MURANO_PASSWORD'] = @saved_pwd

    ENV['MURANO_CONFIGFILE'] = @saved_cfg
  end

  it 'Creates a file ' do
    tmpfile = Dir.tmpdir + '/pwtest' # This way because Tempfile.new creates.
    begin
      pwd = MrMurano::Passwords.new(tmpfile)
      pwd.save

      expect(FileTest.exist?(tmpfile))
    ensure
      File.unlink(tmpfile) if File.exist? tmpfile
    end
  end

  it "Creates a file in a directory that doesn't exist." do
    tmpfile = Dir.tmpdir + '/deeper/pwtest' # This way because Tempfile.new creates.
    begin
      pwd = MrMurano::Passwords.new(tmpfile)
      pwd.save

      expect(FileTest.exist?(tmpfile))
    ensure
      File.unlink(tmpfile) if File.exist? tmpfile
    end
  end

  it 'Loads a file' do
    Tempfile.open('test') do |tf|
      tf << %(---
this.is.a.host:
  user: password
)
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ps = pwd.get('this.is.a.host', 'user')
      expect(ps).to eq('password')
    end
  end

  it 'Saves a file' do
    Tempfile.open('pstest') do |tf|
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.set('this.is.a.host', 'user3', 'passwords4')
      pwd.save

      File.open(tf.path) do |io|
        data = io.read
        expect(data).to eq(%(---
this.is.a.host:
  user3: passwords4
))
      end
    end
  end

  it 'Writes multiple hosts' do
    Tempfile.open('pwtest') do |tf|
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.set('this.is.a.host', 'user3', 'passwords4')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ps = pwd.get('this.is.a.host', 'user3')
      expect(ps).to eq('passwords4')

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      pwd.set('another.host', 'user9', 'passwords2')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ps = pwd.get('this.is.a.host', 'user3')
      expect(ps).to eq('passwords4')
      ps = pwd.get('another.host', 'user9')
      expect(ps).to eq('passwords2')
    end
  end

  it 'Write multiple users to same host' do
    Tempfile.open('pwstest') do |tf|
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.set('this.is.a.host', 'user3', 'passwords4')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      pwd.set('this.is.a.host', 'user9', 'passwords2')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ps = pwd.get('this.is.a.host', 'user3')
      expect(ps).to eq('passwords4')
      ps = pwd.get('this.is.a.host', 'user9')
      expect(ps).to eq('passwords2')
    end
  end

  it 'lists usernames' do
    Tempfile.open('pwstest') do |tf|
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.set('this.is.a.host', 'user3', 'passwords4')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      pwd.set('this.is.a.host', 'user9', 'passwords2')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ret = pwd.list
      expect(ret).to match(
        'this.is.a.host' => a_collection_containing_exactly('user9', 'user3')
      )
    end
  end

  it 'removes username' do
    Tempfile.open('pwstest') do |tf|
      tf.close

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.set('this.is.a.host', 'user3', 'passwords4')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      pwd.set('this.is.a.host', 'user9', 'passwords2')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      pwd.remove('this.is.a.host', 'user3')
      pwd.save

      pwd = MrMurano::Passwords.new(tf.path)
      pwd.load
      ret = pwd.list
      expect(ret).to match('this.is.a.host' => ['user9'])
    end
  end

  context 'Uses ENV' do
    before(:example) do
      ENV['MR_PASSWORD'] = nil
    end
    after(:example) do
      ENV['MR_PASSWORD'] = nil
    end

    it 'Uses ENV instead' do
      Tempfile.open('test') do |tf|
        tf << %(---
this.is.a.host:
  user: password
        )
        tf.close

        ENV['MURANO_PASSWORD'] = 'a test!'
        pwd = MrMurano::Passwords.new(tf.path)
        pwd.load
        expect(pwd).not_to receive(:warning)
        ps = pwd.get('this.is.a.host', 'user')
        expect(ps).to eq('a test!')
        ENV['MURANO_PASSWORD'] = nil
      end
    end

    it 'Uses ENV instead, even with empty file' do
      Tempfile.open('test') do |tf|
        tf.close

        ENV['MURANO_PASSWORD'] = 'a test!'
        pwd = MrMurano::Passwords.new(tf.path)
        pwd.load
        expect(pwd).not_to receive(:warning)
        ps = pwd.get('this.is.a.host', 'user')
        expect(ps).to eq('a test!')
        ENV['MURANO_PASSWORD'] = nil

        data = IO.read(tf.path)
        expect(data).to eq('')
      end
    end

    it 'Warns about migrating' do
      Tempfile.open('test') do |tf|
        tf.close

        ENV['MR_PASSWORD'] = 'a test!'
        pwd = MrMurano::Passwords.new(tf.path)
        pwd.load
        expect(pwd).to receive(:warning).once
        ps = pwd.get('this.is.a.host', 'user')
        expect(ps).to eq('a test!')
      end
    end
  end
end

