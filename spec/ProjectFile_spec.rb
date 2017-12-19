# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

#require 'erb'
require 'fileutils'
#require 'tempfile'
require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/ProjectFile'
require '_workspace'

RSpec.describe MrMurano::ProjectFile do
  context 'Basics ' do
    include_context 'WORKSPACE'
    before(:example) do
      $cfg = MrMurano::Config.new
      $cfg.load
      $cfg['user.name'] = 'bob@builder.co'
      $project = nil
    end

    context 'No files to load' do
      context 'Defaults' do
        before(:example) do
          @pjf = MrMurano::ProjectFile.new
          #@pjf.load
        end
        it 'Info' do
          expect(@pjf.get('info.name')).to eq('project')
          expect(@pjf.get('info.summary')).to eq('One line summary of project')
          expect(@pjf.get('info.description')).to eq("In depth description of project\n\nWith lots of details.")
          expect(@pjf.get('info.authors')).to eq(['bob@builder.co'])
          expect(@pjf.get('info.version')).to eq('1.0.0')
        end

        it 'Assets' do
          # Because defaults before load() are all nil, the default_value_for method
          # is called.
          expect(@pjf).to receive(:default_value_for).with('assets.location').and_return('here')
          expect(@pjf.get('assets.location')).to eq('here')

          expect(@pjf).to receive(:default_value_for).with('assets.include').and_return(['here'])
          expect(@pjf.get('assets.include')).to eq(['here'])

          expect(@pjf).to receive(:default_value_for).with('assets.exclude').and_return(['here'])
          expect(@pjf.get('assets.exclude')).to eq(['here'])

          expect(@pjf).to receive(:default_value_for).with('assets.default_page').and_return('here')
          expect(@pjf.get('assets.default_page')).to eq('here')
        end

        it 'Modules' do
          # Because defaults before load() are all nil, the default_value_for method
          # is called.
          expect(@pjf).to receive(:default_value_for).with('modules.location').and_return('here')
          expect(@pjf.get('modules.location')).to eq('here')

          expect(@pjf).to receive(:default_value_for).with('modules.include').and_return(['here'])
          expect(@pjf.get('modules.include')).to eq(['here'])

          expect(@pjf).to receive(:default_value_for).with('modules.exclude').and_return(['here'])
          expect(@pjf.get('modules.exclude')).to eq(['here'])
        end

        it 'Routes' do
          # Because defaults before load() are all nil, the default_value_for method
          # is called.
          expect(@pjf).to receive(:default_value_for).with('routes.location').and_return('here')
          expect(@pjf.get('routes.location')).to eq('here')

          expect(@pjf).to receive(:default_value_for).with('routes.include').and_return(['here'])
          expect(@pjf.get('routes.include')).to eq(['here'])

          expect(@pjf).to receive(:default_value_for).with('routes.exclude').and_return(['here'])
          expect(@pjf.get('routes.exclude')).to eq(['here'])
        end

        it 'Services' do
          # Because defaults before load() are all nil, the default_value_for method
          # is called.
          expect(@pjf).to receive(:default_value_for).with('services.location').and_return('here')
          expect(@pjf.get('services.location')).to eq('here')

          expect(@pjf).to receive(:default_value_for).with('services.include').and_return(['here'])
          expect(@pjf.get('services.include')).to eq(['here'])

          expect(@pjf).to receive(:default_value_for).with('services.exclude').and_return(['here'])
          expect(@pjf.get('services.exclude')).to eq(['here'])
        end
      end

      context 'Bad Keys' do
        before(:example) do
          @pjf = MrMurano::ProjectFile.new
        end
        it 'Empty' do
          expect { @pjf.get('') }.to raise_error('Empty key')
        end
        it 'No dot' do
          expect { @pjf.get('info') }.to raise_error('Missing dot')
        end
        it 'Undefined key' do
          expect { @pjf.get('info.bob') }.to raise_error("no member 'bob' in struct")
        end
        it 'Undefined section' do
          expect { @pjf.get('sob.include') }.to raise_error(NameError)
        end
        it 'Missing key' do
          expect { @pjf.get('info.') }.to raise_error('Missing key')
        end
        it 'Missing section' do
          expect { @pjf.get('.include') }.to raise_error("no member '' in struct")
        end
      end

      context 'default_value_for mapping' do
        before(:example) do
          @pjf = MrMurano::ProjectFile.new
        end

        it 'returns nil for unmapped key.' do
          expect(@pjf.default_value_for('foooood')).to be_nil
        end

        it 'hits $cfg if mapped key' do
          expect($cfg).to receive(:get).with('location.endpoints').and_return('beef')
          expect(@pjf.default_value_for('routes.location')).to eq('beef')
        end

        it 'returns array for split values' do
          expect($cfg).to receive(:get).with('endpoints.searchFor').and_return('beef')
          expect(@pjf.default_value_for('routes.include')).to eq(['beef'])

          expect($cfg).to receive(:get).with('endpoints.searchFor').and_return('beef and potatoes')
          expect(@pjf.default_value_for('routes.include')).to eq(%w[beef and potatoes])
        end
      end
    end

    context 'Calling load' do
      before(:example) do
        @pjf = MrMurano::ProjectFile.new
      end

      context 'load just meta' do
        before(:example) do
          src = File.join(@testdir, 'spec/fixtures/ProjectFiles/only_meta.yaml')
          dst = File.join(@project_dir, 'meta.murano')
          FileUtils.copy(src, dst)
          @pjf.load
        end
        it 'has the name' do
          expect(@pjf.get('info.name')).to eq('tested')
        end
        it 'has version' do
          expect(@pjf.get('info.version')).to eq('1.56.12')
        end

        it 'fails back to $cfg' do
          expect(@pjf).to receive(:default_value_for).with('routes.include').and_return(['here'])
          expect(@pjf.get('routes.include')).to eq(['here'])
        end
      end

      context 'load custom routes' do
        before(:example) do
          src = File.join(@testdir, 'spec/fixtures/ProjectFiles/with_routes.yaml')
          dst = File.join(@project_dir, 'meta.murano')
          FileUtils.copy(src, dst)
          @pjf.load
        end
        it 'has the name' do
          expect(@pjf.get('info.name')).to eq('tested')
        end
        it 'has version' do
          expect(@pjf.get('info.version')).to eq('1.56.12')
        end
        it 'does not fail back to $cfg' do
          expect(@pjf).to_not receive(:default_value_for)
          expect(@pjf.get('routes.include')).to eq(['custom_api.lua'])
        end
      end

      it 'reports validation errors' do
        src = File.join(@testdir, 'spec/fixtures/ProjectFiles/invalid.yaml')
        dst = File.join(@project_dir, 'meta.murano')
        FileUtils.copy(src, dst)

        saved = $stderr
        $stderr = StringIO.new
        expect(@pjf.load).to eq(-5)
        expect($stderr.string).to match(
          %r{The property '#/info' did not contain a required property of 'description'}
        )
        $stderr = saved
      end
    end
  end

  context 'Solutionfile 0.2.0' do
    include_context 'WORKSPACE'
    before(:example) do
      $cfg = MrMurano::Config.new
      $cfg.load
      $cfg['user.name'] = 'bob@builder.co'
      $project = nil
      @pjf = MrMurano::ProjectFile.new
    end

    it 'Reports validation errors' do
      src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.2.0_invalid.json')
      dst = File.join(@project_dir, 'Solutionfile.json')
      FileUtils.copy(src, dst)
      saved = $stderr
      $stderr = StringIO.new
      @pjf.load
      expect($stderr.string).to match(
        %r{The property '#/' did not contain a required property of 'custom_api'}
      )
      $stderr = saved
    end

    it 'loads with truncated version' do
      src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.2.json')
      dst = File.join(@project_dir, 'Solutionfile.json')
      FileUtils.copy(src, dst)
      saved = $stderr
      $stderr = StringIO.new
      @pjf.load
      expect($stderr.string).to eq('')
      $stderr = saved
    end

    context 'loads' do
      before(:example) do
        src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.2.0.json')
        dst = File.join(@project_dir, 'Solutionfile.json')
        FileUtils.copy(src, dst)
        @pjf.load
      end
      it 'defines assets' do
        expect(@pjf.get('assets.default_page')).to eq('index.html')
        expect(@pjf.get('assets.location')).to eq('public')
        expect(@pjf.get('assets.include')).to eq(['**/*'])
      end

      it 'defines routes' do
        expect(@pjf['routes.location']).to eq('.')
        expect(@pjf.get('routes.include')).to eq(['sample_api.lua'])
      end

      it 'defines modules' do
        expect(@pjf['modules.location']).to eq('.')
        expect(@pjf['modules.include']).to match_array(
          ['modules/debug.lua', 'modules/listen.lua', 'modules/util.lua']
        )
      end

      it 'defines services' do
        expect(@pjf['services.location']).to eq('.')
        expect(@pjf['services.include']).to match_array(
          ['event_handler/product.lua', 'event_handler/timer.lua']
        )
      end
    end
  end

  context 'Solutionfile 0.3.0' do
    include_context 'WORKSPACE'
    before(:example) do
      $cfg = MrMurano::Config.new
      $cfg.load
      $cfg['user.name'] = 'bob@builder.co'
      $project = nil
      @pjf = MrMurano::ProjectFile.new
    end

    it 'Reports validation errors' do
      src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.3.0_invalid.json')
      dst = File.join(@project_dir, 'Solutionfile.json')
      FileUtils.copy(src, dst)
      saved = $stderr
      $stderr = StringIO.new
      @pjf.load
      expect($stderr.string).to match(
        %r{The property '#/' did not contain a required property of 'routes'}
      )
      $stderr = saved
    end

    it 'loads with truncated version' do
      src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.3.json')
      dst = File.join(@project_dir, 'Solutionfile.json')
      FileUtils.copy(src, dst)
      saved = $stderr
      $stderr = StringIO.new
      @pjf.load
      expect($stderr.string).to eq('')
      $stderr = saved
    end

    context 'loads' do
      before(:example) do
        src = File.join(@testdir, 'spec/fixtures/SolutionFiles/0.3.0.json')
        dst = File.join(@project_dir, 'Solutionfile.json')
        FileUtils.copy(src, dst)
        @pjf.load
      end
      it 'defines assets' do
        expect(@pjf.get('assets.default_page')).to eq('index.html')
        expect(@pjf.get('assets.location')).to eq('public')
        expect(@pjf.get('assets.include')).to eq(['**/*'])
      end

      it 'defines routes' do
        expect(@pjf['routes.location']).to eq('.')
        expect(@pjf.get('routes.include')).to eq(['sample_api.lua'])
      end

      it 'defines modules' do
        expect(@pjf['modules.location']).to eq('.')
        expect(@pjf['modules.include']).to match_array(
          [
            'modules/debug.lua',
            'modules/listen.lua',
            'modules/util.lua',
          ]
        )
      end

      it 'defines services' do
        expect(@pjf['services.location']).to eq('.')
        expect(@pjf['services.include']).to match_array(
          [
            'event_handler/product.lua',
            'event_handler/timer.lua',
          ]
        )
      end
    end
  end
end

