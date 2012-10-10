require 'spec_helper'

describe IndexHelper do
  describe "#store_locator_title" do

    context "when current system locale is us" do
      it "returns the Store Locator title" do
        helper.should_receive(:is_us?).and_return true
        helper.store_locator_title.should eql "Store Locator"
      end
    end

    context "when current system locale is uk" do
      it "returns the Stockist List title" do
        helper.should_receive(:is_us?).and_return false
        helper.should_receive(:is_uk?).and_return true
        helper.store_locator_title.should eql "Stockist List"
      end
    end

    context "when current system locale is ellison retailer" do
      it "returns the Distributor Locator title" do
        helper.should_receive(:is_us?).and_return false
        helper.should_receive(:is_uk?).and_return false
        helper.should_receive(:is_er?).and_return true
        helper.store_locator_title.should eql "Distributor Locator"
      end
    end

    context "when current system locale is not a Ellison Retailer and it's not from us or uk" do
      it "returns the Store Locator title" do
        helper.should_receive(:is_us?).and_return false
        helper.should_receive(:is_uk?).and_return false
        helper.should_receive(:is_er?).and_return false
        helper.store_locator_title.should eql "Store Locator"
      end
    end
  end

  describe "#store_locator_tab" do

    context "When the current system is a sizzix from the US" do
      it "returns the link Store Locator tab" do
        helper.should_receive(:is_sizzix_us?).and_return true
        helper.store_locator_tab.should eql link_to "Stores", "#stores"
      end
    end

    context "when current system is ellison education us" do
      it "returns the link Store Locator tab" do
        helper.should_receive(:is_sizzix_us?).and_return false
        helper.should_receive(:is_ee_us?).and_return true
        helper.store_locator_tab.should eql link_to "Stores", "#stores"
      end
    end

    context "when current system is sizzix uk" do
      it "returns the link Store Locator tab" do
        helper.should_receive(:is_sizzix_us?).and_return false
        helper.should_receive(:is_ee_us?).and_return false
        helper.should_receive(:is_sizzix_uk?).and_return true
        helper.store_locator_tab.should eql link_to "Stockist List", "#stores"
      end
    end

    context "when current system is ellison education uk" do
      it "returns the link Store Locator tab" do
        helper.should_receive(:is_sizzix_us?).and_return false
        helper.should_receive(:is_sizzix_uk?).and_return false
        helper.should_receive(:is_ee_us?).and_return false
        helper.should_receive(:is_ee_uk?).and_return true
        helper.store_locator_tab.should eql link_to "Stockist List", "#stores"
      end
    end

    context "when current system is ellison retailers us or uk" do
      it "returns the link Store Locator tab" do
        helper.should_receive(:is_sizzix_us?).and_return false
        helper.should_receive(:is_sizzix_uk?).and_return false
        helper.should_receive(:is_ee_us?).and_return false
        helper.should_receive(:is_ee_uk?).and_return false
        helper.should_receive(:is_er?).and_return true
        helper.store_locator_tab.should eql link_to "Distributors", "#stores"
      end
    end
  end

  describe "#additional_text_for" do
    let(:store) { double('as store') }

    it "should return title when store is only a catalog company" do
      store.stub(:catalog_company).and_return true
      store.stub(:webstore).and_return false
      helper.additional_text_for(store).should eql content_tag(:span, "Contact store to request a catalog", class: "nav_clearance")
    end

    it "should return title when store is only a catalog company and web store" do
      store.stub(:catalog_company).and_return true
      store.stub(:webstore).and_return true
      helper.additional_text_for(store).should eql content_tag(:span, "Online and Catalog", class: "nav_clearance")
    end

    it "should not return title when store is only a web store" do
      store.stub(:catalog_company).and_return false
      store.stub(:webstore).and_return true
      helper.additional_text_for(store).should eql nil
    end

    it "should not return title when store is not both web store and  catalog company" do
      store.stub(:catalog_company).and_return false
      store.stub(:webstore).and_return false
      helper.additional_text_for(store).should eql nil
    end
  end

  describe "#retailers_group_with" do

    let(:retailers) { double('as store criteria') }
    let(:countries) { [ "us", "uk" ] }

    it "should return countries in ascending order" do
      retailers.should_receive(:where).with(:country.in => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :asc)
      helper.should_receive(:is_ee_uk?).and_return true
      helper.retailers_group_with(retailers, countries)
    end

    it "should return countries in ascending order" do
      retailers.should_receive(:where).with(:country.in => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :asc)
      helper.should_receive(:is_ee_uk?).and_return false
      helper.should_receive(:is_sizzix_uk?).and_return true
      helper.retailers_group_with(retailers, countries)
    end

    it "should return countries in descending order" do
      retailers.should_receive(:where).with(:country.in => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :desc)
      helper.should_receive(:is_sizzix_uk?).and_return false
      helper.should_receive(:is_ee_uk?).and_return false
      helper.should_receive(:is_ee_us?).and_return true
      helper.retailers_group_with(retailers, countries)
    end

    it "should return countries in descending order" do
      retailers.should_receive(:where).with(:country.in => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :desc)
      helper.should_receive(:is_sizzix_uk?).and_return false
      helper.should_receive(:is_ee_uk?).and_return false
      helper.should_receive(:is_ee_us?).and_return false
      helper.should_receive(:is_sizzix_us?).and_return true
      helper.retailers_group_with(retailers, countries)
    end

    it "should return countries in descending order" do
      retailers.should_receive(:where).with(:country.in => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :desc)
      helper.should_receive(:is_sizzix_uk?).and_return false
      helper.should_receive(:is_sizzix_us?).and_return false
      helper.should_receive(:is_ee_uk?).and_return false
      helper.should_receive(:is_ee_us?).and_return false
      helper.should_receive(:is_er_us?).and_return true
      helper.retailers_group_with(retailers, countries)
    end

  end

  describe "#retailers_group_without" do

    let(:retailers) { double('as store criteria') }
    let(:countries) { [ "us", "uk" ] }

    it "should return countries in ascending order" do
      retailers.should_receive(:where).with(:country.nin => countries).and_return(retailers)
      retailers.should_receive(:order_by).with(:country => :asc)
      retailers_group_without retailers, countries
    end

  end

end
