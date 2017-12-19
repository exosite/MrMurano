# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'fileutils'
require 'open3'
require 'cmd_common'

RSpec.describe 'murano init', :cmd do
  include_context 'CI_CMD'

  def expected_response_when_ids_found_in_config(
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
      t.a_string_matching(/Linked '\w+' to '\w+'\n/),
      "\n",
      t.a_string_matching(/Created default event handler\n/),
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
      # 2017-12-15: Currently:
      #   services{product.id}_event.lua
      #   services/user_account.lua
      #   specs/resources.yaml
      "Updating local product resources\n",
      t.a_string_starting_with('Adding item '),
      t.a_string_starting_with('Adding item '),
      "Synced 3 items\n",
      "\n",
    ]
    expecting += [
      "Success!\n",
      "\n",
      t.a_string_matching(/\s+Business ID: \w+\n/),
      t.a_string_matching(/(\s+Application ID: \w+\n)?/),
      t.a_string_matching(/(\s+Product ID: \w+\n)?/),
      "\n",
    ]
    expecting
  end

  it %(Won't init in HOME (gracefully)) do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out).to eq('')
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  context 'in empty directory', :needs_password do
    context 'with' do
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
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name, '-y'))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it 'existing project' do
        # The test account will have one business, one product, and one application.
        # So it won't ask any questions.
        out, err, status = Open3.capture3(capcmd('murano', 'init'))
        expecting = expected_response_when_ids_found_in_config(
          self,
          has_one_each_soln: true,
        )
        out_lines = out.lines.map { |line| strip_fancy(line) }
        expect(out_lines).to match_array(expecting)
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        expect(File.directory?('.murano')).to be true
        expect(File.exist?('.murano/config')).to be true
        expect(File.directory?('routes')).to be true
        expect(File.directory?('services')).to be true
        expect(File.directory?('files')).to be true
        expect(File.directory?('modules')).to be true
        expect(File.directory?('specs')).to be true
      end
    end

    context 'without', :needs_password do
      before(:example) do
        murano_solutions_expunge_yes
        @applctn_name = rname('initCreatingApp')
        @product_name = rname('initCreatingPrd')
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name, '-y'))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it 'existing project' do
        # The test account will have one business.
        # It will ask to create an application and product.
        # MAGIC_NUMBER: !!!! the 8 is hardcoded indention here !!!!
        #   (removes the leading whitespace from the <<-EOT heredoc)
        data = <<-DATA.gsub(/^ {8}/, '')
        #{@applctn_name}
        #{@product_name}
        DATA
        # 2017-07-05: [lb] added line numbers to use debugger to help maintain this test.
        out, err, status = Open3.capture3(capcmd('murano', 'init'), stdin_data: data)
        expecting = expected_response_when_ids_found_in_config(
          self,
          has_no_solutions: true,
          expect_proj_file_write: true,
        )
        out_lines = out.lines.map { |line| strip_fancy(line) }
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
        #  a_string_starting_with("Linked '"), # 17
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
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        expect(File.directory?('.murano')).to be true
        expect(File.exist?('.murano/config')).to be true
        expect(File.directory?('routes')).to be true
        expect(File.directory?('services')).to be true
        expect(File.directory?('files')).to be true
        expect(File.directory?('modules')).to be true
        expect(File.directory?('specs')).to be true
      end
    end
  end

  context 'in existing project directory', :needs_password do
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
          out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @product_name, '-y'))
          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to eq(0)
        end

        if defined?(@applctn_name)
          out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @applctn_name, '-y'))
          expect(out).to eq('')
          expect(err).to eq('')
          expect(status.exitstatus).to eq(0)
        end
      end
    end

    it 'without ProjectFile' do
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      the_expected = expected_response_when_ids_found_in_config(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
      )
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(the_expected)
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      expect(File.directory?('.murano')).to be true
      expect(File.exist?('.murano/config')).to be true
      expect(File.directory?('routes')).to be true
      expect(File.directory?('services')).to be true
      expect(File.directory?('files')).to be true
      expect(File.directory?('modules')).to be true
      expect(File.directory?('specs')).to be true
    end

    it 'with ProjectFile' do
      FileUtils.copy(File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml'), 'test.murano')
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expected_response_when_ids_found_in_config(
        self,
        expect_rebasing: true,
        expect_proj_file_write: false,
        creates_some_default_directories: true,
      )
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(expected)
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      expect(File.directory?('.murano')).to be true
      expect(File.exist?('.murano/config')).to be true
      expect(File.directory?('routes')).to be true
      expect(File.directory?('services')).to be true
      expect(File.directory?('files')).to be true
      expect(File.directory?('modules')).to be true
      expect(File.directory?('specs')).to be true
    end

    it 'with SolutionFile 0.2.0' do
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          default_page: 'index.html',
          file_dir: 'files',
          custom_api: 'routes/manyRoutes.lua',
          modules: {
            table_util: 'modules/table_util.lua',
          },
          event_handler: {
            device: {
              datapoint: 'services/devdata.lua',
            },
          },
        }.to_json
      end
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      # NOTE: This tests uses an old Solutionfile.json, config v0.2.0, and it
      # downloads Lua scripts to the root of the project directory. Just FYI.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expected_response_when_ids_found_in_config(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
      )
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(expected)
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      expect(File.directory?('.murano')).to be true
      expect(File.exist?('.murano/config')).to be true
      expect(File.directory?('routes')).to be true
      expect(File.directory?('services')).to be true
      expect(File.directory?('files')).to be true
      expect(File.directory?('modules')).to be true
      expect(File.directory?('specs')).to be true
    end

    it 'with SolutionFile 0.3.0' do
      File.open('Solutionfile.json', 'wb') do |io|
        io << {
          default_page: 'index.html',
          assets: 'files',
          routes: 'routes/manyRoutes.lua',
          modules: {
            table_util: 'modules/table_util.lua',
          },
          services: {
            device: {
              datapoint: 'services/devdata.lua',
            },
          },
          version: '0.3.0',
        }.to_json
      end
      # The test account will have one business, one product, and one application.
      # So it won't ask any questions.
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expected = expected_response_when_ids_found_in_config(
        self,
        expect_rebasing: true,
        creates_some_default_directories: true,
      )
      out_lines = out.lines.map { |line| strip_fancy(line) }
      expect(out_lines).to match_array(expected)
      expect(err).to eq('')
      expect(status.exitstatus).to eq(0)

      expect(File.directory?('.murano')).to be true
      expect(File.exist?('.murano/config')).to be true
      expect(File.directory?('routes')).to be true
      expect(File.directory?('services')).to be true
      expect(File.directory?('files')).to be true
      expect(File.directory?('modules')).to be true
      expect(File.directory?('specs')).to be true
    end
  end
end

