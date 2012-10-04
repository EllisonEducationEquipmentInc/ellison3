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
end
