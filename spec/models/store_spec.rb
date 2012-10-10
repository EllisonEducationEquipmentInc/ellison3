require 'spec_helper'

describe Store do
  subject { Store.new }

  describe "initialization" do
    its(:physical_store) { should be_false }
    its(:product_line)   { should eql([]) }
    its(:catalog_company) { should be_false }
    its(:webstore) { should be_false }
    its(:active)   { should be_true }
  end

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:brands) }
    it { should validate_presence_of(:agent_type) }
    it { should ensure_inclusion_of(:agent_type).in_array(["Distributor", "Sales Representative", "Authorized Reseller"]) }
  end

  describe ".active" do

    it "should not return stores when systems enabled is empty" do
      FactoryGirl.create(:store)
      FactoryGirl.create(:store)
      Store.active.count.should eql(0)
    end

    it "should not return stores when active is false" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus], active: false)
      store2 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus], active: false)
      Store.active.to_a.should =~ []
    end

    it "should return store only when systems enabled has szus" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus])
      store2 = FactoryGirl.create(:store, systems_enabled: %w[szuk eeus eeuk erus])
      Store.active.to_a.should =~ [store1]
    end

    it "should return store only in sites in systems enabled" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus erus])
      store2 = FactoryGirl.create(:store, systems_enabled: %w[szus])
      Store.active.to_a.should =~ [store1, store2]
    end
  end

  describe ".online_retailers" do

    it "should not return physical stores" do
      physical = FactoryGirl.create(:all_system_store, physical_store: true)
      Store.online_retailers.to_a.should =~ [ ]
    end

    it "should not return inactive web store" do
      webstore = FactoryGirl.create(:all_system_store, webstore: true, active: false)
      catalog_company = FactoryGirl.create(:all_system_store, catalog_company: true)
      Store.online_retailers.to_a.should =~ [ catalog_company ]
    end

    it "should not return inactive catalog_company" do
      webstore = FactoryGirl.create(:all_system_store, webstore: true)
      catalog_company = FactoryGirl.create(:all_system_store, catalog_company: true, active: false)
      Store.online_retailers.to_a.should =~ [ webstore ]
    end

    it "returns either retailers web store or catalog company" do
      catalog_company = FactoryGirl.create(:all_system_store, catalog_company: true)
      physical = FactoryGirl.create(:all_system_store, physical_store: true)
      webstore = FactoryGirl.create(:all_system_store, webstore: true)
      Store.online_retailers.to_a.should =~ [ webstore, catalog_company ]
    end

    it "returns retailers grouped by country and ordered by name" do
      usa_products = FactoryGirl.create(:all_system_store, name: "Products", catalog_company: true, country: "United States")
      usa_matz     = FactoryGirl.create(:all_system_store, name: "Matz", catalog_company: true, country: "United States")
      co_zixs      = FactoryGirl.create(:all_system_store, name: "Zixs", catalog_company: true, country: "Colombia")
      uk_alo       = FactoryGirl.create(:all_system_store, name: "Alo", webstore: true, country: "United Kingdom")
      aus_prado    = FactoryGirl.create(:all_system_store, name: "Prado", webstore: true, country: "Australia")

      Store.online_retailers.to_a.should eql [ aus_prado, co_zixs, uk_alo, usa_matz, usa_products ]
    end

  end

  describe ".distinct_countries" do

    it "should return countries of the stores in ascending order with unique values" do
      FactoryGirl.create(:all_system_store, physical_store: true, country: "United States")
      FactoryGirl.create(:all_system_store, physical_store: true, country: "United Kingdom")
      FactoryGirl.create(:all_system_store, physical_store: true, country: "United Kingdom")
      FactoryGirl.create(:all_system_store, physical_store: true, country: "Australia")
      Store.distinct_countries.should eql [ "Australia", "United Kingdom", "United States" ]
    end

    it "should not include countries for web stores" do
      FactoryGirl.create(:all_system_store, webstore: true, country: "United States")
      FactoryGirl.create(:all_system_store, physical_store: true, country: "Australia")
      Store.distinct_countries.should =~ [ "Australia" ]
    end

    it "should not return any countries when no stores have been created" do
      Store.distinct_countries.should =~ [ ]
    end

  end

end
