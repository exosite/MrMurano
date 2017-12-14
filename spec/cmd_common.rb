# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'highline'
# Set HighLine's $terminal global.
require 'highline/import'
require 'os'
require 'pathname'
require 'shellwords'
require 'timeout'
require 'tmpdir'
require 'webmock/rspec'

require 'MrMurano/Config'

# Prevent Commander from registering its at_exit hook.
# - Also print warning if spec exits, which rspec doesn't see as wrong.
# - Note that this comes before importing Commander.
$exited_abnormally = false
at_exit do
  if $exited_abnormally
    warn('¡!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
    warn('¡Unexpected spec exit killed rspec!')
    warn('¡!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
  end
end
alias original_at_exit at_exit unless defined?(original_at_exit)
def at_exit(*args, &block)
  #original_at_exit *args, &block
  # pass!
end

require 'MrMurano/Commander-Entry'

module Commander
  class Command
    attr_writer :when_called
    #def when_called=(args)
    #  @when_called = args
    #end

    def peek_when_called
      @when_called
    end
  end

  class Runner
    def force_args(args)
      @args = args
    end
  end
end

RSpec.shared_context 'CI_CMD' do
  # capcmd makes an Open3-ready `murano` command from a list of args.
  def capcmd(*args)
    args = [args] unless args.is_a? Array
    args.flatten!
    testdir = File.realpath(@testdir.to_s)
    if ENV['CI_MR_EXE'].nil?
      args[0] = File.join(testdir, 'bin', args[0])
      args.unshift('ruby', "-I#{File.join(testdir, 'lib')}")
    else
      args[0] = File.join(testdir, (args[0] + '.exe'))
    end
    args.push '--trace'
    args.push '-c', 'fullerror'
    # The spinner output would make it hard to write expects().
    args.push '--no-progress'

    if Gem.win_platform?
      cmd = args.map do |i|
        case i
        when /[ ]/
          %("#{i}")
        when /[\*#]/
          i.gsub(/([\*#])/, '^\1')
        else
          i
        end
      end.join(' ')
    else
      cmd = Shellwords.join(args)
    end
    #pp cmd
    cmd
  end

  # *** Utility fcns: symlinks.

  # Makes a symlink to the /tmp project dir.
  def mk_symlink
    # Make it easy to debug tests, e.g., add breakpoint before capcmd('murano', ...)
    # run test, then open another terminal window and `cd /tmp/murcli-test`.
    # NOTE: When run on Jenkins, Dir.tmpdir() returns the path to the project directory!
    #   Since this is for DEVs only, we can hack around this.
    tmpdir = Dir.tmpdir()
    return unless tmpdir == '/tmp'
    @dev_symlink = File.join(tmpdir, 'murcli-test')
    FileUtils.rm(@dev_symlink, force: true)
    begin
      FileUtils.ln_s(Dir.pwd, @dev_symlink)
    rescue NotImplementedError => err
      # This happens on Windows...
      require 'rbconfig'
      # Check the platform, e.g., "linux-gnu", or other.
      #is_windows = (
      #  RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      #)
      unless OS.windows?
        warn(
          'Unexpected: ln_s failed on non-Windows machine / ' \
          "host_os: #{RbConfig::CONFIG['host_os']} / err: #{err}"
        )
      end
    end
  end

  # Removes the /tmp project directory symlink.
  def rm_symlink
    FileUtils.rm(@dev_symlink, force: true) if defined?(@dev_symlink)
  end

  # *** Utility fcns: Murano Solutions management: create/delete/expunge.

  def murano_solutions_expunge_yes
    out, err, status = Open3.capture3(
      capcmd('murano', 'solutions', 'expunge', '-y')
    )
    expect(out).to \
      eq('').or \
        eq("No solutions found\n").or \
          match(/^Deleted [\d]+ solutions/)
    expect(strip_color(err)).to eq('').or eq("No solutions found\n")
    expect(status.exitstatus).to eq(0).or eq(1)
  end

  def project_up(skip_link: false)
    # Preemptive clean up!
    murano_solutions_expunge_yes if defined?(PRE_EXPUNGE) && PRE_EXPUNGE

    @proj_name_prod = rname('MurCLITestProd')
    out, err, status = Open3.capture3(
      capcmd('murano', 'product', 'create', @proj_name_prod, '--save')
    )
    expect(err).to eq('')
    expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    @proj_name_appy = rname('MurCLITestAppy')
    out, err, status = Open3.capture3(
      capcmd('murano', 'application', 'create', @proj_name_appy, '--save')
    )
    expect(err).to eq('')
    soln_id = out
    expect(soln_id.chomp).to match(/^[a-zA-Z0-9]+$/)
    expect(status.exitstatus).to eq(0)

    project_up_link unless skip_link
  end

  def project_up_link
    out, err, status = Open3.capture3(capcmd('murano', 'assign', 'set'))
    #expect(out).to a_string_starting_with("Linked product #{@proj_name_prod}")
    olines = out.lines
    expect(strip_fancy(olines[0])).to eq(
      "Linked '#{@proj_name_prod}' to '#{@proj_name_appy}'\n"
    )
    expect(olines[1]).to eq("Created default event handler\n")
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  def project_down
    return if defined?(PRE_EXPUNGE) && PRE_EXPUNGE

    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', @proj_name_appy, '-y')
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)

    out, err, status = Open3.capture3(
      capcmd('murano', 'solution', 'delete', @proj_name_prod, '-y')
    )
    expect(out).to eq('')
    expect(err).to eq('')
    expect(status.exitstatus).to eq(0)
  end

  # Utility fcns: Strings.

  # rname makes a random Murano-acceptable Solution name.
  def rname(name)
    #"#{name}-#{Random.new.rand.hash.abs.to_s(16)}"
    # MUR-2454: Product name may only contain letters and numbers.
    #"#{name}#{Random.new.rand.hash.abs.to_s(16)}"
    # MUR-XXXX: Product name must be lowercase.
    # 2017-06-01: From [cr]: "I'll be having bizapi convert to lower case
    #  in the short term, and pegasus is updating to allow upper case."
    #  LATER: Remove .downcase once PAAS fixed.
    "#{name.downcase}#{Random.new.rand.hash.abs.to_s(16)}"
  end

  def strip_color(str)
    str.gsub(/\e\[(\d+)m/, '')
  end

  def strip_fancy(str)
    # Windows has a complaint about the fancy quotes if you don't encode!, which is
    #
    #   expected: "Linked \u2018syncdowntestprd1e8b4034\u2019
    #               to \u2018syncdowntestapp23d5135b\u2019\n"
    #        got: "Linked \xE2\x80\x98syncdowntestprd1e8b4034\xE2\x80\x99
    #               to \xE2\x80\x98syncdowntestapp23d5135b\xE2\x80\x99\n"
    #
    # or, to put it another way,
    #
    #     -Linked ?syncdowntestprd1e8b4034? to ?syncdowntestapp23d5135b?
    #     +Linked Î“Ã‡Ã¿syncdowntestprd1e8b4034Î“Ã‡Ã– to Î“Ã‡Ã¿syncdowntestapp23d5135bÎ“Ã‡Ã–
    #
    # which we can solve with an encode call. (Or but using norm quotes.)
    str.encode!('UTF-8', 'UTF-8').tr(%(‘), %(')).tr(%(’), %('))
  end

  # *** rb-commander goodies

  def murano_command_run(cmd, *args)
    murano_command_runner(cmd, *args)
  end

  def murano_command_exits(cmd, *args)
    murano_command_runner(cmd, *args, wont_run: true)
  end

  def murano_command_wont_parse(cmd, *args)
    murano_command_runner(cmd, *args, wont_parse: true)
  end

  def murano_command_runner(cmd, *args, wont_run: false, wont_parse: false)
    # This is a functional test, so tell WebMock to back off.
    # FIXME: Remember the setting and re-enable.
    WebMock.allow_net_connect!

    wasout = $stdout
    waserr = $stderr
    wasterm = $terminal
    tmpout = StringIO.new
    tmperr = StringIO.new

    # Commander's `say` calls HighLine's $terminal.say, so redirect that, too.
    hline = HighLine.new($stdin, tmpout)
    $terminal = hline
    # DEVs: If you set a byebug break after this point, the byebug will
    #   show when the code breaks, but you'll see no echo or output. So
    #   comment this code out if you're debugging.
    $stdout = tmpout
    $stderr = tmperr

    # When Commander is loaded, it sets an at_exit hook, which we monkey
    # patch in ReCommander. Since Config.validate_cmd is called before
    # at_exit, it uses runner.command_exit to tell ReCommander's at_exit
    # monkey patch not to call Commander.run!. Via rspec, we don't use the
    # at_exit hook, or ReCommander.
    if $cfg.nil?
      $cfg = MrMurano::Config.new(::Commander::Runner.instance)
      $cfg.load
    end
    $cfg['tool.no-progress'] = true
    $cfg.validate_cmd(cmd)
    runner = ::Commander::Runner.instance
    unless defined?(runner.command_exit) && runner.command_exit
      # Commander's at_exit hook calls runner.run! which runs the command
      # that was determined with Commander was loaded. I [lb] tried a few
      # different ways to reset Runner.instance, but nothing worked; our
      # best bet is to just call the command directly.
      the_cmd = command(cmd.to_sym)
      when_called = the_cmd.peek_when_called.dup

      runner.force_args(args.dup)
      $exited_abnormally = true
      #runner.parse_global_options
      if wont_parse
        expect { runner.old_parse_global_options }.to raise_error(SystemExit)
      else
        runner.old_parse_global_options
        runner.remove_global_options runner.options, args
        if wont_run
          expect { the_cmd.run(*args) }.to raise_error(SystemExit)
        else
          the_cmd.run(*args)
        end
      end
      $exited_abnormally = false

      # Reset proxy_options otherwise Commander::Command.call
      # uses them the next time this command is called.
      the_cmd.proxy_options = []
      the_cmd.when_called = when_called
    end
    runner.command_exit = nil

    # Ruby provides std i/o constants, so we could do this:
    #   $stdout, $stderr = STDOUT, STDERR
    $stdout = wasout
    $stderr = waserr
    $terminal = wasterm
    [strip_color(tmpout.string), strip_color(tmperr.string)]
  end

  def cmd_verify_help(cmd_name)
    stdout, stderr = murano_command_run(cmd_name)
    expect(stdout).to start_with(
      "  NAME:\n\n    murano #{cmd_name}\n\n  DESCRIPTION:\n\n    "
    )
    expect(stderr).to eq('')
  end

  # *** before() and around()

  # Before: Load Config.
  before(:example) do
    $cfg = MrMurano::Config.new
    $cfg.load
  end

  # Around: Make project dir under /tmp.
  around(:example) do |ex|
    # Load the byebug library now, before changing directories.
    # This sets Setting[:histfile]. Within byebug, try `show histfile`.
    # Make sure this is set now, otherwise, byebug crashes, e.g.,
    #   <Errno::ENOENT: No such file or directory @ rb_sysopen -
    #       /tmp/d20170830-10087-h7tq6a/project/.byebug_history>
    # This happens if the first call to byebug is after the chdir.
    # Byebug creates the histfile in the tmp dir. So the next time
    # the method containing `byebug` is called, it's from within a
    # different tmp dir, and the old tmp dir has been removed. So
    # byebug crashes trying to access the old, missing histfile.
    require 'byebug/settings/histfile'
    _ignored = ::Byebug::HistfileSetting::DEFAULT

    @testdir = Pathname.new(Dir.pwd).realpath
    Dir.mktmpdir do |hdir|
      ENV['HOME'] = hdir
      Dir.chdir(hdir) do
        Dir.mkdir('.murano')
        @tmpdir = File.join(hdir, 'project')
        Dir.mkdir(@tmpdir)
        Dir.chdir(@tmpdir) do
          mk_symlink
          # Timeout after 300 secs/5 mins.
          Timeout.timeout(300) do
            ex.run
          end
          rm_symlink
        end
      end
    end
  end
end

