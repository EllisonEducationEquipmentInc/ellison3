require 'spec_helper'

feature "Stores", js: true do
  context "Store locator" do
    before do
      @store1 = FactoryGirl.create(:physical_us_store)
      @store2 = FactoryGirl.create(:physical_us_store, systems_enabled: %w[szuk eeus eeuk erus])
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

    context "when there's a physical store" do
      before do
        @store = FactoryGirl.create :physical_us_store
        visit stores_path
      end

      scenario "I should see the 'stores' tab when there are/aren't any distributors" do
        page.should have_link("Stores")
        page.should_not have_link("Online Retailers")
      end
    end
  end

  context "As a user when I search for a US Store with a sales representative" do

    before do
      @store = FactoryGirl.create(:sales_representative_physical_us_store)
    end

    scenario "I can see the serving representative states" do
      visit stores_path
      select "United States", :from => 'country'
      fill_in 'zip_code', with: @store.zip_code
      wait_until do
        page.should have_content @store.name
        page.should have_content "Representative Serving: #{@store.representative_serving_states.join(", ")}"
      end
    end
  end

  context "As A user when I visit the store path" do
    context "When I'm in the Store Tab" do
      before do
        @store = FactoryGirl.create(:sales_representative_physical_us_store)
        visit stores_path
      end

      scenario "I Should see the revelant store details" do
        select "United States", :from => 'country'
        fill_in 'zip_code', with: @store.zip_code
        check_content_for @store
      end
    end

    context "when I'm in the Online Retailers Tab" do
      before do
        @online_retailer = FactoryGirl.create(:sales_representative_webstore_us_store)
        visit stores_path
      end

      scenario "I Should see the Online Retailers revelant store details" do
        click_on "Online Retailers"
        check_content_for @online_retailer
      end
    end
  end

  context "user should see the store logo and excellence level images" do
    before do
      @online_retailer = FactoryGirl.create :sales_representative_webstore_us_store
    end

    scenario "I should see the store logo" do
      pending "this test should be fixed or removed, it is failing since images are no longer checked in with the app"

      @online_retailer.update_attributes image_filename: "public/bag.jpg", logo_url: "/images/stores/logo/logo_public/bag.jpg"
      visit stores_path
      click_on "Online Retailers"
      page.should have_image @online_retailer.logo_url
    end

    [["Executive", ".icon_excellence-level_executive"],
     ["Preferred", ".icon_excellence-level_preferred"],
     ["Elite", ".icon_excellence-level_elite"],
     ["A Cut Above", ".icon_excellence-level_a-cut-above"]].each do |excellence_level, klass|
      scenario "I should see the store #{excellence_level} excellence image" do
        set_request_host("sizzix.com")
        @online_retailer.update_attribute :excellence_level, excellence_level
        visit stores_path
        click_on "Online Retailers"
        page.should have_css klass
      end
    end
  end

  def check_content_for store
    wait_until do
      page.should have_content store.name
      page.should have_content store.address1
      page.should have_content store.address2
      page.should have_content store.city
      page.should have_content store.state
      page.should have_content store.zip_code
      page.should have_content store.country
      page.should have_content "Representative Serving: #{store.representative_serving_states.join(", ")}"
      page.should have_content store.phone
      page.should have_content store.fax
      page.should have_content "Contact Via Email"
      page.should have_content "Get Directions" if store.physical_store?
      page.should have_content "Browse their website"
    end
  end
end

