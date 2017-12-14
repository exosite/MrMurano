# Copyright © 2016-2017 Exosite LLC. All Rights Reserved
# License: PROPRIETARY. See LICENSE.txt.
# frozen_string_literal: true

# vim:tw=0:ts=2:sw=2:et:ai
# Unauthorized copying of this file is strictly prohibited.

require 'highline/import'
require 'MrMurano/version'
require 'MrMurano/Config'
require 'MrMurano/Account'
require '_workspace'

MISSING_BIZ_ID_MSG = MrMurano::Business.missing_business_id_msg

RSpec.describe MrMurano::Business do
  include_context 'WORKSPACE'
  before(:example) do
    @saved_cfg = ENV['MURANO_CONFIGFILE']
    ENV['MURANO_CONFIGFILE'] = nil
    $cfg = MrMurano::Config.new
    $cfg.load
    $cfg['net.host'] = 'bizapi.hosted.exosite.io'
    $cfg['business.id'] = 'XYZxyz'
    $cfg['product.id'] = 'XYZ'

    @biz = MrMurano::Business.new
    allow(@biz).to receive(:token).and_return('TTTTTTTTTT')
  end
  after(:example) do
    ENV['MURANO_CONFIGFILE'] = @saved_cfg
  end

  it 'lists products' do
    prodlist = [
      { bizid: 'XYZxyz',
        type: 'product',
        pid: 'ABC',
        modelId: 'cde',
        label: 'fts',
        api_id: 'XYZ',
        sid: 'XYZ',
        name: 'XYZ', },
      { bizid: 'XYZxyz',
        type: 'product',
        pid: 'fgh',
        modelId: 'ijk',
        label: 'lua-test',
        api_id: 'XYZ',
        sid: 'XYZ',
        name: 'XYZ', },
    ]
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).to_return(body: prodlist)

    solz = []
    solz << MrMurano::Product.new(prodlist[0])
    solz << MrMurano::Product.new(prodlist[1])

    ret = @biz.products
    expect(ret).to eq(solz)
  end

  it 'lists products; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@biz).to receive(:debug).with('Getting all solutions of type product')
    expect { @biz.products }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'creates product' do
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    stub_request(
      :post, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).with(
      body: { label: 'one', type: 'product' }
    ).to_return(body: '{"id": "abc123def456ghi78", "name": "one"}')

    prod = @biz.new_product('one')
    expect(prod.valid?).to be true
  end

  it 'creates product; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    expect { @biz.new_product('one') }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'deletes product' do
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    stub_request(
      :delete, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/one'
    ).to_return(body: '')

    ret = @biz.delete_product('one')
    expect(ret).to eq({})
  end

  it 'deletes product; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    expect { @biz.delete_product('one') }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  # *** :applications type solutions

  it 'lists applications' do
    # NOTE: Need to use symbols, not strings, for keys, because
    #       http.rb::json_opts() specifies :symbolize_names => true.
    appllist = [
      { bizid: 'XYZxyz',
        type: 'application',
        domain: 'XYZxyz.apps.exosite.io',
        api_id: 'ACBabc',
        sid: 'ACBabc',
        name: 'ijk', },
      { bizid: 'XYZxyz',
        type: 'application',
        domain: 'XYZxyz.apps.exosite.io',
        api_id: 'DEFdef',
        sid: 'DEFdef',
        name: 'lmn', },
    ]
    solnlist = [
      { bizid: 'XYZxyz',
        type: 'product',
        pid: 'ABC',
        modelId: 'cde',
        label: 'fts',
        name: 'fgh', },
    ]
    solnlist.concat appllist
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).to_return(body: solnlist)

    solz = []
    #solz << MrMurano::Product.new(solnlist[0])
    solz << MrMurano::Application.new(appllist[0])
    solz << MrMurano::Application.new(appllist[1])

    ret = @biz.applications
    expect(ret).to eq(solz)
  end

  it 'lists applications; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@biz).to receive(:debug).with('Getting all solutions of type application')
    expect { @biz.applications }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'creates application' do
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    stub_request(
      :post, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).with(
      body: { label: 'one', type: 'application' }
    ).to_return(body: '{"id": "abc123def456ghi78", "name": "one"}')

    appl = @biz.new_application('one')
    expect(appl.valid?).to be true
  end

  it 'creates application; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    # LATER: Re-enable using 'ONe' instead of 'one' after upcase fixed in pegasus_registry.
    expect { @biz.new_application('one') }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'deletes application' do
    stub_request(
      :delete, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/ONe'
    ).to_return(body: '')

    ret = @biz.delete_application('ONe')
    expect(ret).to eq({})
  end

  it 'deletes application; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @biz.delete_application('ONe') }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  # *** :all type solutions

  it 'lists solutions' do
    # http.rb::json_opts() sets :symbolize_names=>true, so use symbols, not strings.
    prodlist = [
      { bizid: 'XYZxyz',
        type: 'product',
        domain: 'ABCabc.m2.exosite.io',
        api_id: 'ABCabc',
        sid: 'ABCabc',
        name: 'XXX', },
    ]
    appllist = [
      { bizid: 'XYZxyz',
        type: 'application',
        domain: 'XYZxyz.apps.exosite.io',
        api_id: 'DEFdef',
        sid: 'DEFdef',
        name: 'XXX', },
    ]
    solnlist = prodlist + appllist
    stub_request(
      :get, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).to_return(body: solnlist)

    solz = []
    solz << MrMurano::Product.new(prodlist[0])
    solz << MrMurano::Application.new(appllist[0])

    solz = @biz.solutions
    expect(solz).to eq(solz)
  end

  it 'lists solutions; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect(@biz).to receive(:debug).with('Getting all solutions of type all')
    expect { @biz.solutions }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'creates solution' do
    stub_request(
      :post, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).with(body: { label: 'one', type: 'product' })
      .to_return(body: '{"id": "abc123def456ghi78", "name": "one"}')

    sol = @biz.new_solution!('one', :product)
    expect(sol.valid?).to be true
    expect(sol.api_id).to eq('abc123def456ghi78')
  end

  still_broken = true
  if still_broken
    # LATER: Re-enable after upcase fixed in pegasus_registry.
    it 'creates solution; with upper case' do
      # 2017-07-03: Murano appears to return the id nowadays, so added body.
      stub_request(
        :post, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
      ).with(body: { label: 'ONe', type: 'product' })
        .to_return(body: '{"id": "abc123def456ghi78", "name": "ONe"}')

      expect { @biz.new_solution!('ONe', :product) }.to_not raise_error
    end
  else
    it 'creates solution; with uppercase' do
      expect { @biz.new_solution!('oNeTWO', :product) }.to raise_error(
        MrMurano::Product.new.name_validate_help
      )
    end
  end

  it 'creates solution; with numbers and dashes' do
    stub_request(
      :post, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/'
    ).with(body: { label: 'ONe-8796-gkl', type: 'product' })
      .to_return(body: '{"id": "abc123def456ghi78", "name": "ONe-8796-gkl"}')

    # 2017-05-26: Dashes forbidden! MUR-1994
    #expect { @biz.new_solution!('ONe-8796-gkl', :product) }.to_not raise_error
    expect { @biz.new_solution!('ONe-8796-gkl', :product) }.to raise_error(
      MrMurano::Product.new.name_validate_help
    )
  end

  it 'creates solution; that is too long' do
    expect { @biz.new_solution!('o' * 70, :product) }.to raise_error(
      MrMurano::Product.new.name_validate_help
    )
  end

  it 'creates solution; with underscore' do
    expect { @biz.new_solution!('one_two', :product) }.to raise_error(
      MrMurano::Product.new.name_validate_help
    )
  end

  it 'creates solution; with digit first' do
    expect { @biz.new_solution!('1two', :product) }.to raise_error(
      MrMurano::Product.new.name_validate_help
    )
  end

  it 'creates solution; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @biz.new_solution!('one', :product) }.to raise_error(MISSING_BIZ_ID_MSG)
  end

  it 'deletes solution' do
    stub_request(
      :delete, 'https://bizapi.hosted.exosite.io/api:1/business/XYZxyz/solution/one'
    ).to_return(body: '')

    ret = @biz.delete_solution('one')
    expect(ret).to eq({})
  end

  it 'deletes solution; without biz.id' do
    allow($cfg).to receive(:get).with('business.id').and_return(nil)
    expect { @biz.delete_solution('one') }.to raise_error(MISSING_BIZ_ID_MSG)
  end
end

