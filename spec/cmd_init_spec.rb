# Last Modified: 2017.08.03 /coding: utf-8
# frozen_string_literal: true

# Copyright © 2016-2017 Exosite LLC.
# License: MIT. See LICENSE.txt.
#  vim:tw=0:ts=2:sw=2:et:ai

require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'murano init', :cmd do
  include_context "CI_CMD"

  def expectedResponseWhenIdsFoundInConfig(
    t,
    expect_rebasing: false,
    has_one_each_soln: false,
    has_no_solutions: false,
    expect_proj_file_write: true,
    creates_some_default_directories: false,
    local_files_found: false,
    local_files_found_application: false,
    local_files_found_product: false
  )
    expecting = []
    expecting += [
      "\n", # 0
    ]
    if !expect_rebasing
      expecting += [
        t.a_string_starting_with('Creating project at '), # 1
      ]
    else
      expecting += [
        t.a_string_starting_with('Rebasing project at '), # 1
      ]
    end
    expecting += [
      "\n", # 2
      t.a_string_starting_with('Found User '), # 3
      "\n", # 4
      t.a_string_starting_with('Found Business '), # 5
      "\n", # 6
    ]
    if has_one_each_soln
      expecting += [
        a_string_starting_with('This business has one Application. Using '), # 7
        "\n", # 8
        a_string_starting_with('This business has one Product. Using '), # 9
        "\n", # 10
      ]
    elsif has_no_solutions
      # 2017-07-05: line numbers are for: context "without", :needs_password do / it "existing project" do
      expecting += [
        "This business does not have any applications. Let's create one\n", # 7
        "\n", # 8
        "Please enter the Application name: \n", # 9
        a_string_starting_with('Created new Application: '), # 10
        "\n", # 11
        "This business does not have any products. Let's create one\n", # 12
        "\n", # 13
        "Please enter the Product name: \n", # 14
        a_string_starting_with('Created new Product: '), # 15
        "\n", # 16
      ]
    else
      expecting += [
        t.a_string_starting_with('Found Application '), # 7
        "\n", # 8
        t.a_string_starting_with('Found Product '), # 9
        "\n", # 10
      ]
    end
    expecting += [
      t.a_string_matching(%r{Linked ‘\w+’ to ‘\w+’\n}),
      "\n",
      t.a_string_matching(%r{Created default event handler\n}),
      "\n",
    ]
    if expect_proj_file_write
      expecting += [
        "Writing Project file to project.murano\n",
        "\n",
      ]
    end
    if !creates_some_default_directories
      expecting += [
        "Created default directories\n",
      ]
    else
      expecting += [
        "Created some default directories\n",
      ]
    end
    expecting += [
      "\n",
    ]
    if local_files_found || local_files_found_application
      expecting += [
        "Skipping Application Event Handlers: local files found\n",
        "\n",
      ]
    end
    if local_files_found || local_files_found_product
      expecting += [
        "Skipping Product Event Handlers: local files found\n",
        "\n",
      ]
    end
    expecting += [
      t.a_string_matching(%r{Adding item \w+_event\n}),
      # Order not consistent...
      #"Adding item tsdb_exportJob\n",
      #"Adding item timer_timer\n",
      #"Adding item user_account\n",
      t.a_string_starting_with('Adding item '),
      t.a_string_starting_with('Adding item '),
      t.a_string_starting_with('Adding item '),
      "Synced 4 items\n",
      "\n",
    ]
    expecting += [
      "Success!\n",
      "\n",
      t.a_string_matching(%r{\s+Business ID: \w+\n}),
      t.a_string_matching(%r{(\s+Application ID: \w+\n)?}),
      t.a_string_matching(%r{(\s+Product ID: \w+\n)?}),
      "\n",
    ]
    expecting
  end

  def murano_solutions_expunge_yes
    out, err, status = Open3.capture3(capcmd('murano', 'solutions', 'expunge', '-y'))
    expect(out).to eq('').
      or eq("No solutions found\n").
      or eq("Deleted 1 solution\n").
      or eq("Deleted 2 solutions\n")
    expect(err).to eq('').
      or eq("\e[31mNo solutions found\e[0m\n")
    expect(status.exitstatus).to eq(0).or eq(1)
  end

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out).to eq("")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  context "in empty directory", :needs_password do
    context "with" do
      # Setup a product and application to use.
      # Doing this in a context with before&after so that after runs even when test
      # fails.
      before(:example) do
        murano_solutions_expunge_yes

        @applctn_name = rname('initEmptyApp')
        out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        @product_name = rname('initEmptyPrd')
        out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        # delete all of this so it is a empty directory.
        FileUtils.remove_entry('.murano')
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it "existing project" do
        # The test account will have one business, one product, and one application.
        # So it won't ask any questions.
        out, err, status = Open3.capture3(capcmd('murano', 'init'))
        expecting = expectedResponseWhenIdsFoundInConfig(
          self,
          has_one_each_soln: true,
        )
        out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
        expect(out_lines).to match_array(expecting)
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        expect(File.directory?(".murano")).to be true
        expect(File.exist?(".murano/config")).to be true
        expect(File.directory?("routes")).to be true
        expect(File.directory?("services")).to be true
        expect(File.directory?("files")).to be true
        expect(File.directory?("modules")).to be true
        expect(File.directory?("specs")).to be true
      end
    end

    context "without", :needs_password do
      before(:example) do
        murano_solutions_expunge_yes
        @applctn_name = rname('initCreatingApp')
        @product_name = rname('initCreatingPrd')
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it "existing project" do
        # The test account will have one business.
        # It will ask to create an application and product.
        # MAGIC_NUMBER: !!!! the 8 is hardcoded indention here !!!!
        #   (removes the leading whitespace from the <<-EOT heredoc)
        data = <<-EOT.gsub(/^ {8}/, '')
        #{@applctn_name}
        #{@product_name}
        EOT
        # 2017-07-05: [lb] added line numbers to use debugger to help maintain this test.
        out, err, status = Open3.capture3(capcmd('murano', 'init'), stdin_data: data)
        expecting = expectedResponseWhenIdsFoundInConfig(
          self,
          has_no_solutions: true,
          expect_proj_file_write: true,
        )
        out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
        expect(out_lines).to match_array(expecting)
        #expect(out.lines).to match_array([
        #  "\n", # 0
        #  a_string_starting_with('Creating project at '), # 1
        #  "\n", # 2
        #  a_string_starting_with('Found User '), # 3
        #  "\n", # 4
        #  a_string_starting_with('Found Business '), # 5
        #  "\n", # 6
        #  "This business does not have any applications. Let's create one\n", # 7
        #  "\n", # 8
        #  "Please enter the Application name: \n", # 9
        #  a_string_starting_with('Created new Application: '), # 10
        #  "\n", # 11
        #  "This business does not have any products. Let's create one\n", # 12
        #  "\n", # 13
        #  "Please enter the Product name: \n", # 14
        #  a_string_starting_with('Created new Product: '), # 15
        #  "\n", # 16
        #  a_string_starting_with('Linked ‘'), # 17
        #  "\n", # 18
        #  "Created default event handler\n", # 19
        #  "\n", # 20
        #  "Writing Project file to project.murano\n", # 21
        #  "\n", # 22
        #  "Created default directories\n", # 23
        #  "\n", # 24
        #  "Success!\n", # 25
        #  "\n", # 26
        #  a_string_starting_with('         Business ID: '), # 27
        #  a_string_starting_with('      Application ID: '), # 28
        #  a_string_starting_with('          Product ID: '), # 29
        #  "\n", # 30
        #])
        expect(err).to eq("")
        expect(status.exitstatus).to eq(0)

        expect(File.directory?(".murano")).to be true
        expect(File.exist?(".murano/config")).to be true
        expect(File.directory?("routes")).to be true
        expect(File.directory?("services")).to be true
        expect(File.directory?("files")).to be true
        expect(File.directory?("modules")).to be true
        expect(File.directory?("specs")).to be true
      end
    end
  end

  context "in existing project directory", :needs_password do
    before(:example) do
      murano_solutions_expunge_yes

      FileUtils.cp_r(File.join(@testdir, 'spec/fixtures/syncable_content/.'), '.')
      FileUtils.move('assets', 'files')

      @applctn_name = rname('initEmptyApp')
      out, err, status = Open3.capture3(capcmd('murano', 'application', 'create', @applctn_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)

      @product_name = rname('initEmptyPrd')
      out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @product_name, '--save'))
      expect(err).to eq('')
      expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
      expect(status.exitstatus).to eq(0)
    end
    after(:example) do
      Dir.chdir(ENV['HOME']) do
        if defined?(@product_name)
          out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name))
          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to eq(0)
        end

        if defined?(@applctn_name)
          out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name))
          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to eq(0)
        end
      end
    end

    it "without ProjectFile" do
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      the_expected = expectedResponseWhenIdsFoundInConfig(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
        # Because the /tmp/murcli-test/services directory is empty,
        # murano init *will* download all the event handlers.
        #local_files_found: true,
      )
      out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
      expect(out_lines).to match_array(the_expected)
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with ProjectFile" do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expectedResponseWhenIdsFoundInConfig(
        self,
        expect_rebasing: true,
        expect_proj_file_write: false,
        creates_some_default_directories: true,
        # Because the /tmp/murcli-test/services directory is empty,
        # murano init *will* download all the event handlers.
        #local_files_found: true,
      )
      out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
      expect(out_lines).to match_array(expected)
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with SolutionFile 0.2.0" do
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :file_dir => 'files',
          :custom_api => 'routes/manyRoutes.lua',
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :event_handler => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          }
        }.to_json
      end
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expectedResponseWhenIdsFoundInConfig(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
        # Because the /tmp/murcli-test/services directory is empty,
        # murano init *will* download all the event handlers.
        ##local_files_found_application: true,
        #local_files_found_product: true,
      )
      out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
      expect(out_lines).to match_array(expected)
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end

    it "with SolutionFile 0.3.0" do
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          :default_page => 'index.html',
          :assets => 'files',
          :routes => 'routes/manyRoutes.lua',
          :modules => {
            :table_util => 'modules/table_util.lua'
          },
          :services => {
            :device => {
              :datapoint => 'services/devdata.lua'
            }
          },
          :version => '0.3.0',
        }.to_json
      end
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expectedResponseWhenIdsFoundInConfig(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
        # Because the /tmp/murcli-test/services directory is empty,
        # murano init *will* download all the event handlers.
        ##local_files_found_application: true,
        #local_files_found_product: true,
      )
      out_lines = out.lines.map { |line| line.encode!('UTF-8', 'UTF-8') }
      expect(out_lines).to match_array(expected)
      expect(err).to eq("")
      expect(status.exitstatus).to eq(0)

      expect(File.directory?(".murano")).to be true
      expect(File.exist?(".murano/config")).to be true
      expect(File.directory?("routes")).to be true
      expect(File.directory?("services")).to be true
      expect(File.directory?("files")).to be true
      expect(File.directory?("modules")).to be true
      expect(File.directory?("specs")).to be true
    end
  end

end

