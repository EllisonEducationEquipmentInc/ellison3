require 'spec_helper'

describe Store do

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

    context "when physical store is false by default" do
      it "should not validate presence of address1" do
        subject.valid?
        subject.errors[:address1].should_not include("can't be blank")
      end

      it "should not validate presence of country" do
        subject.valid?
        subject.errors[:country].should_not include("can't be blank")
      end

      it "should not validate presence of city" do
        subject.valid?
        subject.errors[:city].should_not include("can't be blank")
      end
    end

    context "when physical store is true" do

      context "on initialization" do

        before do
          stub_invalid_geocode
        end

        subject { Store.new(physical_store: true) }

        it "should validate presence of address1" do
          subject.valid?
          subject.errors[:address1].should include("can't be blank")
        end

        it "should validate presence of country" do
          subject.valid?
          subject.errors[:country].should include("can't be blank")
        end

        it "should validate presence of city" do
          subject.valid?
          subject.errors[:city].should include("can't be blank")
        end

        it "should validate location" do
          store = FactoryGirl.build(:store, physical_store: true, address1: "affda;fj", country: "affda;fj", city: "affda;fj", zip_code: "affda;fj")
          store.should_not be_valid
          store.save.should be_false
          store.errors[:location].should include("Invalid address, could not be Geocoded.")
        end

      end

      context "on update" do

        it "should validate location on update physical store" do
          Geokit::Geocoders::MultiGeocoder.stub(:geocode).and_return(double('as response', success: true, lat: 37.3203455, lng: -122.0328205))
          store = FactoryGirl.create(:store, physical_store: true)
          store.address1 = "affda;fj"
          store.country = "affda;fj"
          store.city = "affda;fj"
          store.zip_code = "affda;fj"
          stub_invalid_geocode
          store.should_not be_valid
          store.save.should be_false
          store.errors[:location].should include("Invalid address, could not be Geocoded.")
        end

        it "should validate location on upgrade webstore to physical store" do
          stub_invalid_geocode
          store = FactoryGirl.create(:store, webstore: true, address1: "affda;fj", country: "affda;fj", city: "affda;fj", zip_code: "affda;fj" )
          store.should be_valid
          store.webstore = false
          store.physical_store = true
          store.should_not be_valid
          store.save.should be_false
          store.errors[:location].should include("Invalid address, could not be Geocoded.")
        end

      end

    end

    it "should respond to geocode" do
      expect { Geokit::Geocoders::MultiGeocoder.geocode }.to_not raise_error NoMethodError
    end

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

  describe ".catalog_companies" do
    describe "when there are no stores with catalog company" do
      before do
        FactoryGirl.create :store
      end

      specify{ Store.catalog_companies.should be_empty }
    end

    describe "when there are stores with catalog company" do
      before do
        @store = FactoryGirl.create :store, catalog_company: true
      end

      specify{ Store.catalog_companies.should include @store }
    end
  end

  describe "#representative_serving_states" do
    before do
      @store = Store.new
      @store.name = 'D-name'
      @store.brands = ["sizzix", "ellison"]
      @states = ["Al", "Fl"]
    end

    describe "when the admin is a Sales representative from the US" do
      before do
        @store.country = 'United States'
        @store.agent_type = 'Sales Representative'
      end

      describe "when the admin hasn't selected any representative state" do
        specify { @store.save.should be_true }
      end

      describe "when the admin has selected Florida and Alabama from the serving representative" do
        before do
          @store.representative_serving_states = @states
        end

        specify { @store.save.should be_true }

        it "has Florida and Alabama as serving representative" do
          @store.save.should be_true
          @store.representative_serving_states.should == @states
        end
      end
    end

    describe "when the admin is not a Sales representative from the US" do
      before do
        @store.country = 'United States'
        @store.agent_type = 'Authorized Reseller'
      end

      describe "when the admin has representative serving states" do
        before do
          @store.representative_serving_states = @states
        end

        specify { @store.save.should be_false }

        it "returns a serving representative error" do
          @store.save
          @store.errors[:base].should include "Admin can't be a serving representative"
        end
      end

      describe "when the admin doesn't have representative serving states" do
        specify { @store.save.should be_true }
      end
    end

    describe "when the admin is a Sales representative but not from the US" do
      before do
        @store.country = 'Colombia'
        @store.agent_type = 'Sales Representative'
      end

      describe "when the admin has representative serving states" do
        before do
          @store.representative_serving_states = @states
        end

        specify { @store.save.should be_false }

        it "returns a serving representative error" do
          @store.save
          @store.errors[:base].should include "Admin can't be a serving representative"
        end
      end

      describe "when the admin doesn't have representative serving states" do
        specify { @store.save.should be_true }
      end
    end
  end

  def stub_invalid_geocode
    Geokit::Geocoders::MultiGeocoder.stub(:geocode).and_return(double('as response', success: false))
  end
end
