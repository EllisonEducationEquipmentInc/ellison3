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
end
