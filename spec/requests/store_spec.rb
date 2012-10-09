require 'spec_helper'

feature "Stores", js: true do
  context "Store locator" do
    before do
      @store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
                                   physical_store: true, product_line: ["sizzix", "eclipse"])

      @store2 = FactoryGirl.create(:store, systems_enabled: %w[szuk eeus eeuk erus],
                                   physical_store: true, product_line: ["sizzix", "eclipse"])
    end

    scenario "as a user I should not see disabled stores" do
      visit stores_path
      select 'United States', from: 'country'
      fill_in 'zip_code', with: @store1.zip_code
      wait_until do
        page.should have_content @store1.name
      end
    end

    context "Enabled stores" do
      before do
        @store2.update_attribute(:systems_enabled, ["szus"])
      end

      scenario "as a user I should see enabled stores" do
        visit stores_path
        select "United States", :from => 'country'
        fill_in 'zip_code', with: @store2.zip_code
        wait_until do
          page.should have_content @store1.name
          page.should have_content @store2.name
        end
      end
    end
  end

  context "Store locator tabs" do

    scenario "when there's no physical stores I shouldn't see the stores tab" do
      visit stores_path
      page.should_not have_link("Stores")
    end

    scenario "when physical stores I should see stores tab" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
                                  physical_store: true, product_line: ["Sizzix", "eclipse"])

      visit stores_path
      page.should have_link("Stores")
      page.should_not have_link("Online Retailers")
    end

    scenario "when distributors I should see stores tab" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
                                  physical_store: true, product_line: ["Sizzix", "eclipse"])

      visit stores_path
      page.should have_link("Stores")
      page.should_not have_link("Online Retailers")
    end

    scenario "when no distributors I should see stores tab" do
      store1 = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
                                  physical_store: true, product_line: ["Sizzix", "eclipse"])

      visit stores_path
      page.should have_link("Stores")
      page.should_not have_link("Online Retailers")
    end
  end

  context "As a user when I search for a US Store with a sales representative" do

    before do
      @states = ["Al", "Fl"]
      @store = FactoryGirl.create(:store, systems_enabled: %w[szus szuk eeus eeuk erus],
                                  physical_store: true, product_line: ["sizzix", "eclipse"],
                                  agent_type: 'Sales Representative', representative_serving_states: @states)
    end

    scenario "I can see the serving representative states" do
      visit stores_path
      select "United States", :from => 'country'
      fill_in 'zip_code', with: @store.zip_code
      wait_until do
        page.should have_content @store.name
        page.should have_content "Representative Serving: #{@states.join(", ")}"
      end
    end
  end
end

