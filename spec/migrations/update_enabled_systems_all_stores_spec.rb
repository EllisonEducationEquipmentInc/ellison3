require 'spec_helper'
require File.join(File.dirname(__FILE__), "..", "..", "db", "migrate", "20121018163445_update_enabled_systems_all_stores")

describe UpdateEnabledSystemsAllStores do

  describe "up" do

    context "When agent type is Authorized Reseller" do

      it "should enable the stores to Sizzix US site and Sizzix UK site when brand is Sizzix" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["eeus", "eeuk", "erus"], brands: ["sizzix"])
        store2 = FactoryGirl.create(:store, agent_type: "Sales Representative", systems_enabled: ["erus"])
        store3 = FactoryGirl.create(:store, agent_type: "Distributor", systems_enabled: ["erus"])

        UpdateEnabledSystemsAllStores.up_without_benchmarks
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ store2, store3 ]
      end

      it "should enable the stores to Ellison Education US site and Ellison Education UK site when brand is Ellison" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["szus", "szuk", "erus"], brands: ["ellison"])
        store2 = FactoryGirl.create(:store, agent_type: "Sales Representative", systems_enabled: ["erus"])
        store3 = FactoryGirl.create(:store, agent_type: "Distributor", systems_enabled: ["erus"])

        UpdateEnabledSystemsAllStores.up_without_benchmarks
        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ store2, store3 ]
      end

      it "should enable the stores to EEUS, EEUK, SZUS and SZUK when brand is Ellison and Sizzix" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["szus", "szuk", "erus"], brands: ["ellison", "sizzix"])
        store2 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["erus"], brands: ["ellison"])
        store3 = FactoryGirl.create(:store, agent_type: "Sales Representative", systems_enabled: ["erus"])
        store4 = FactoryGirl.create(:store, agent_type: "Distributor", systems_enabled: ["erus"])

        UpdateEnabledSystemsAllStores.up_without_benchmarks
        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ store1, store2 ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ store1, store2 ]
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ store3, store4 ]
      end

    end

    context "When agent type is Distributor or Sales Representatives" do

      it "should enable the stores to Ellison Retailer US site" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["szus"])
        store2 = FactoryGirl.create(:store, agent_type: "Sales Representative", systems_enabled: ["szus"])
        store3 = FactoryGirl.create(:store, agent_type: "Distributor", systems_enabled: ["szus"])

        UpdateEnabledSystemsAllStores.up_without_benchmarks

        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ store2, store3 ]
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ store1 ]
      end

    end

    context "When systems enabled are not set" do

      it "should enable the stores at the appropriate sites" do
        store1 = FactoryGirl.build(:store, agent_type: "Authorized Reseller", systems_enabled: nil)
        store2 = FactoryGirl.build(:store, agent_type: "Sales Representative", systems_enabled: nil)
        store3 = FactoryGirl.build(:store, agent_type: "Distributor", systems_enabled: nil)
        store1.save(:validate => false)
        store2.save(:validate => false)
        store3.save(:validate => false)

        UpdateEnabledSystemsAllStores.up_without_benchmarks

        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ store2, store3 ]
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ store1 ]
      end

    end

    context "When brands are not set" do
      before do
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
      end

      specify { expect { UpdateEnabledSystemsAllStores.up_without_benchmarks }.to_not raise_error }

    end

  end

  describe "down" do

    context "When agent type is Authorized Reseller" do

      it "should remove stores from sites Sizzix US site and Sizzix UK site when brand is Sizzix" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["eeus", "eeuk", "szus", "szuk"], brands: ["sizzix"])

        UpdateEnabledSystemsAllStores.down_without_benchmarks
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ store1 ]
      end

      it "should remove stores from sites  Ellison Education US site and Ellison Education UK site when brand is Ellison" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["eeus", "eeuk", "szus", "szuk"], brands: ["ellison"])

        UpdateEnabledSystemsAllStores.down_without_benchmarks
        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ store1 ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ store1 ]
      end

      it "should remove stores from sites EEUS, EEUK, SZUS and SZUK when brand is Ellison and Sizzix" do
        store1 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["szus", "szuk"], brands: ["ellison", "sizzix"])
        store2 = FactoryGirl.create(:store, agent_type: "Authorized Reseller", systems_enabled: ["eeus", "eeuk"], brands: ["ellison"])

        UpdateEnabledSystemsAllStores.down_without_benchmarks

        Store.where(:systems_enabled.in => ['eeus']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['eeuk']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['szus']).to_a.should =~ [ ]
        Store.where(:systems_enabled.in => ['szuk']).to_a.should =~ [ ]
      end

    end

    context "When agent type is Distributor or Sales Representatives" do

      it "should remove stores from Ellison Retailer US site" do
        store2 = FactoryGirl.create(:store, agent_type: "Sales Representative", systems_enabled: ["erus"])
        store3 = FactoryGirl.create(:store, agent_type: "Distributor", systems_enabled: ["erus"])

        UpdateEnabledSystemsAllStores.down_without_benchmarks

        Store.where(:systems_enabled.in => ['erus']).to_a.should =~ [ ]
      end

    end

    context "When systems enabled are not set" do

      it "should enable the stores at the appropriate sites" do
        store1 = FactoryGirl.build(:store, agent_type: "Authorized Reseller", systems_enabled: nil)
        store2 = FactoryGirl.build(:store, agent_type: "Sales Representative", systems_enabled: nil)
        store3 = FactoryGirl.build(:store, agent_type: "Distributor", systems_enabled: nil)
        store1.save(:validate => false)
        store2.save(:validate => false)
        store3.save(:validate => false)

        UpdateEnabledSystemsAllStores.down_without_benchmarks

        store1.systems_enabled.should be_nil
        store2.systems_enabled.should be_nil
        store3.systems_enabled.should be_nil
      end

    end

    context "When brands are not set" do
      before do
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
        FactoryGirl.build(:store, agent_type: nil, systems_enabled: nil).save(:validate => false)
      end

      specify { expect { UpdateEnabledSystemsAllStores.down_without_benchmarks }.to_not raise_error }

    end

  end

end