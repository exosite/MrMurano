require 'fileutils'
require 'open3'
require 'pathname'
require 'cmd_common'

RSpec.describe 'mr init', :cmd do
  include_context "CI_CMD"

  it "Won't init in HOME (gracefully)" do
    # this is in the project dir. Want to be in HOME
    Dir.chdir(ENV['HOME']) do
      out, err, status = Open3.capture3(capcmd('murano', 'init'))
      expect(out).to eq("\n")
      expect(err).to eq("\e[31mCannot init a project in your HOME directory.\e[0m\n")
      expect(status.exitstatus).to eq(2)
    end
  end

  context "in empty directory" do
    context "with" do
      # Setup a solution and product to use.
      # Doing this in a context with before&after so that after runs even when test
      # fails.
      before(:example) do
        @project_name = rname('syncdownTest')
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'create', @project_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'create', @project_name, '--save'))
        expect(err).to eq('')
        expect(out.chomp).to match(/^[a-zA-Z0-9]+$/)
        expect(status.exitstatus).to eq(0)
      end
      after(:example) do
        out, err, status = Open3.capture3(capcmd('murano', 'solution', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)

        out, err, status = Open3.capture3(capcmd('murano', 'product', 'delete', @project_name))
        expect(out).to eq('')
        expect(err).to eq('')
        expect(status.exitstatus).to eq(0)
      end

      it "existing solution and product" do
        # The test account will have one business, one product, and one solution.
        # So it won't ask any questions.
        out, err, status = Open3.capture3(capcmd('murano', 'init'))
        expect(out.lines).to match_array([
          "\n",
          a_string_starting_with('Found project base directory at '),
          "\n",
          a_string_starting_with('Using account '),
          a_string_starting_with('Using Business ID already set to '),
          "\n",
          a_string_starting_with('Using Solution ID already set to '),
          "\n",
          a_string_starting_with('Using Product ID already set to '),
          "\n",
          a_string_matching(%r{Ok, In business ID: \w+ using Solution ID: \w+ with Product ID: \w+}),
          "Writing an initial Project file: project.murano\n",
          "Default directories created\n",
        ])
        expect(err).to eq("")
        expect(status.exitstatus).to eq(0)
      end
    end

    it "creates new solution and product"
  end

  context "in existing project directory" do
    it "without ProjectFile"
    it "with ProjectFile"
    it "with SolutionFile 0.2.0"
    it "with SolutionFile 0.3.0"
  end

end
#  vim: set ai et sw=2 ts=2 :
