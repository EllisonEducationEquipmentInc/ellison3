require 'spec_helper'

describe IndexHelper do
  describe "#store_locator_title" do
    context "when current system is ellison retailer us" do
      it "should return proper title when site is configured for ellison retailers" do
        set_current_system 'erus'
        helper.store_locator_title.should eql("Distributor Locator")
      end
    end

    context "when current system is ellison retailer uk" do
      it "should return the proper title for the current system" do
        set_current_system 'eruk'
        helper.store_locator_title.should eql("Distributor Locator")
      end
    end

    context "when current locale is en-US" do
      it "should return the proper title for the current locale" do
        set_current_locale 'en-US'
        helper.store_locator_title.should eql("Store Locator")
      end
    end

    context "when current locale is en-UK" do
      it "should return the proper title for the current locale" do
        set_current_locale 'en-UK'
        helper.store_locator_title.should eql("Stockist List")
      end
    end

    context "when current locale is en-EU" do
      it "should return the proper title for the current locale" do
        set_current_locale 'en-EU'
        helper.store_locator_title.should eql("Stockist List")
      end
    end

    context "when current system is set by default" do
      it "should return the proper title for the current system" do
        set_current_system 'nosystem'
        helper.store_locator_title.should eql("Store Locator")
      end
    end
  end
end