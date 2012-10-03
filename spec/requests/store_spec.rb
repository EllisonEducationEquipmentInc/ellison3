require 'spec_helper'

feature "Stores", js:true do
  context "Store locator" do
    before do
      @store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
        physical_store: true, product_line: ["Sizzix", "eclipse"])

      @store2 = FactoryGirl.create(:store, systems_enabled: %w[szuk eeus eeuk erus],
        address1: "315 5th Avenue", city: "Seattle", country: "Estados Unidos",
          physical_store: true, product_line: ["Sizzix", "eclipse"])
    end

    scenario "as a user I should not see disabled stores" do
      visit stores_path
      select "Estados Unidos", :from => 'country'
      click_link "Search"
      wait_until do
        page.should have_content @store1.name
      end
      page.should_not have_content @store2.name
    end

    context "Enabled stores" do
      before do
        @store2.update_attribute(:systems_enabled, ["szus"])  
      end

      scenario "as a user I should see enabled stores" do
        visit stores_path
        select "Estados Unidos", :from => 'country'
        click_link "Search"
        wait_until do
          page.should have_content @store1.name
          page.should have_content @store2.name
        end
      end
    end
  end
end