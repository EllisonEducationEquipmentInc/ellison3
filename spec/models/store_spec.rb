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
    it { should validate_presence_of(:systems_enabled) }
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

  end

  describe "after save" do

    subject { FactoryGirl.build(:physical_us_store, agent_type: "Sales Representative") }

    context "when the physical US store sales representative is recorded without validations" do
      specify { expect { subject.save(validate: false) }.to_not raise_error }
    end

    context "when the physical US store sales representative is recorded" do
      specify { expect { subject.save }.to_not raise_error }
    end

    it "should set representative serving states geo locations" do
      store = FactoryGirl.build(:sales_representative_physical_us_store)
      store.save
      state_location = [ Geokit::Geocoders::MultiGeocoder.geocode.lat,  Geokit::Geocoders::MultiGeocoder.geocode.lng]
      store.representative_serving_states_locations["Al"].should =~ state_location
      store.representative_serving_states_locations["Fl"].should =~ state_location
    end

  end

  describe ".active" do

    it "should not return stores when systems enabled is empty" do
      FactoryGirl.build(:store, systems_enabled: []).save(validate: false)
      FactoryGirl.build(:store, systems_enabled: []).save(validate: false)
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
      @store = Store.new(systems_enabled: ["szus"])
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

  describe ".distinct_states" do

    it "should return U.S states of the stores in ascending order with unique values" do
      FactoryGirl.create(:all_system_store, physical_store: true, agent_type: 'Sales Representative', representative_serving_states: ["AL", "FL", "CA"])
      FactoryGirl.create(:all_system_store, physical_store: true, state: "AL")
      FactoryGirl.create(:all_system_store, physical_store: true, state: "WY")
      FactoryGirl.create(:all_system_store, physical_store: true, state: "WY")
      Store.distinct_states.should eql [ "AL", "CA", "FL", "WY" ]
    end

    it "should not include states for web stores" do
      FactoryGirl.create(:all_system_store, webstore: true, state: "WY")
      FactoryGirl.create(:all_system_store, physical_store: true, state: "AL")
      Store.distinct_states.should =~ [ "AL" ]
    end

    it "should include states only for United States" do
      FactoryGirl.create(:all_system_store, physical_store: true, state: "WY")
      FactoryGirl.create(:all_system_store, physical_store: true, country: "Australia", state: "FL")
      Store.distinct_states.should =~ [ "WY" ]
    end

    it "should not return any state when no stores have been created" do
      Store.distinct_states.should =~ [ ]
    end

  end

  describe ".all_by_state" do

    it "returns stores from given state and in ascending order by name" do
      store1 = FactoryGirl.create(:all_system_store, physical_store: true, name: "One store", agent_type: 'Sales Representative', representative_serving_states: ["AL", "FL", "CA"])
      store2 = FactoryGirl.create(:all_system_store, physical_store: true, name: "Two Store", state: "AL")
      store3 = FactoryGirl.create(:all_system_store, physical_store: true, name: "Three Store", state: "AL")
      store4 = FactoryGirl.create(:all_system_store, physical_store: true, name: "Four Store", state: "WY")
      Store.all_by_state("AL").to_a.should eql [ store1, store3, store2 ]
    end

    it "should not include stores for web stores" do
      store1 = FactoryGirl.create(:all_system_store, webstore: true, state: "WY")
      store2 = FactoryGirl.create(:all_system_store, physical_store: true, state: "AL")
      Store.all_by_state("AL").to_a.should =~ [ store2 ]
    end

    it "should return only store for United States" do
      store1 = FactoryGirl.create(:all_system_store, physical_store: true, state: "AL", country: "United Kingdom")
      store2 = FactoryGirl.create(:all_system_store, physical_store: true, state: "AL")
      Store.all_by_state("AL").to_a.should =~ [ store2 ]
    end

  end

  describe ".all_by_locations_for" do
    before do
      @code_location = double "as code location"
      @code_location.stub(:lat).and_return(37.328075)
      @code_location.stub(:lng).and_return(-122.032399)

      stub_geocode_position_to 37.325618, -122.043278
      @apple = FactoryGirl.create(:all_system_store, name: "APPLE COMPUTER", physical_store: true)
      stub_geocode_position_to 37.415351, -122.143915
      @hp = FactoryGirl.create(:all_system_store, physical_store: true, address1: "3000 Hanover Street Palo Alto, CA 94304", city: "Palo Alto", zip_code: "94304")
      stub_geocode_position_to 47.663393, -122.297444
      @ms = FactoryGirl.create(:all_system_store, physical_store: true, address1: "2642 Northeast University Village Street, Seattle, WA 98105", city: "Seattle", state: "WA", zip_code: "98105")
    end

    it "should not return stores within 0 miles radius" do
      Store.all_by_locations_for("United States", @code_location, "0").to_a.should =~ [  ]
    end

    it "should return stores within 8 miles radius" do
      Store.all_by_locations_for("United States", @code_location, "8").to_a.should =~ [ @apple ]
    end

    it "should return stores within 20 miles radius" do
      Store.all_by_locations_for("United States", @code_location, "20").to_a.should =~ [ @apple, @hp ]
    end

    it "should return stores within 1000 miles radius" do
      Store.all_by_locations_for("United States", @code_location, "1000").to_a.should =~ [ @apple, @hp, @ms ]
    end

  end

  describe ".stores_for" do
    before do
      stub_geocode_position_to 37.325618, -122.043278
      @apple = FactoryGirl.create(:all_system_store, name: "APPLE COMPUTER", physical_store: true)
      stub_geocode_position_to 37.415351, -122.143915
      @hp = FactoryGirl.create(:all_system_store, physical_store: true, address1: "3000 Hanover Street Palo Alto, CA 94304", city: "Palo Alto", zip_code: "94304")
      stub_geocode_position_to 47.663393, -122.297444
      @ms = FactoryGirl.create(:all_system_store, physical_store: true, address1: "2642 Northeast University Village Street, Seattle, WA 98105", city: "Seattle", state: "WA", zip_code: "98105")
      stub_geocode_position_to 51.290936, -0.755782
      @imb_uk = FactoryGirl.create(:all_system_store, name: "IMB Computer", physical_store: true, address1: "Meudon House Meudon Avenue Farnborough, GU14 7NB", city: "Farnborough", state: "Hampshire", country: "United Kingdom", zip_code: "GU14 7NB")
    end

    it "should not return any store" do
      Store.stores_for(nil, nil, nil, nil, nil, nil).should be_empty
    end

    it "should return stores by name" do
      Store.stores_for("comp", "United States", nil, nil, nil, nil).should =~ [ @apple ]
    end

    it "should return stores by state" do
      Store.stores_for(nil, "United States", "WA", nil, nil, nil).should =~ [ @ms ]
    end

    it "should not return stores when zip code of US is less than five digits" do
      geo_location = double "as code location"
      geo_location.stub(:lat).and_return(@hp.location[0])
      geo_location.stub(:lng).and_return(@hp.location[1])
      Store.stores_for(nil, "United States", nil, "9430", geo_location, "20").should be_empty
    end

    it "should return stores by zip code in US" do
      geo_location = double "as code location"
      geo_location.stub(:lat).and_return(@hp.location[0])
      geo_location.stub(:lng).and_return(@hp.location[1])
      Store.stores_for(nil, "United States", nil, "94304", geo_location, "20").should =~ [ @apple, @hp ]
    end

    it "should return stores by post code in UK" do
      geo_location = double "as code location"
      geo_location.stub(:lat).and_return(@imb_uk.location[0])
      geo_location.stub(:lng).and_return(@imb_uk.location[1])
      Store.stores_for(nil, "United Kingdom", nil, "94304", geo_location, "5").should =~ [ @imb_uk ]
    end

    it "should return all stores in US" do
      Store.stores_for(nil, "United States", nil, nil, nil, nil).should =~ [ @apple, @hp, @ms ]
    end

    it "should return all stores in UK" do
      Store.stores_for(nil, "United Kingdom", nil, nil, nil, nil).should =~ [ @imb_uk ]
    end

    it "should not return any store when no country has been given" do
      Store.stores_for("name", nil, nil, nil, nil, nil).should =~ [ ]
    end

  end

  def stub_invalid_geocode
    Geokit::Geocoders::MultiGeocoder.stub(:geocode).and_return(double('as response', success: false))
  end

  def stub_geocode_position_to lat, lng
    Geokit::Geocoders::MultiGeocoder.stub(:geocode).
      and_return(double('as response', success: true, lat: lat, lng: lng))
  end
end
