require 'spec_helper'

feature "Stores", js:true do
  let(:systems_enabled) { %w[szus szuk eeus eeuk erus] }
  let(:store_permission) { FactoryGirl.build(:permission, name: "stores", write: true, systems_enabled: systems_enabled) }
  let(:admin){ FactoryGirl.create(:admin_user, password: "test1234", permissions: [store_permission]) }
  let(:store) { FactoryGirl.create(:store) }

  before do
    FactoryGirl.create(:country, name: 'Colombia')
    FactoryGirl.create(:country, name: 'United States')
  end

  context "Edit a store" do
    before do
      login_as_admin admin
      visit edit_admin_store_path(store)
    end

    scenario "as a admin I should be able to check in which systems a store can be displayed" do
      (systems_enabled - store.systems_enabled).each do |system|
        page.has_unchecked_field?("store_systems_enabled_#{system}").should be_true
        check "store_systems_enabled_#{system}"
      end

      click_button "Update Store"
      visit edit_admin_store_path(store)

      systems_enabled.each do |system|
        page.has_checked_field?("store_systems_enabled_#{system}").should be_true
      end
    end

    context "As a Sales Representative in a US store" do
      scenario "I should be able to see a Us state drop down list" do
        within ".edit_store" do
          select('Sales Representative', from: 'Agent type')
          select('United States', from: 'Country')
        end
        page.should have_content "Representative serving states"
      end
    end

    context "As a Sales Representative not in a US store", js: true do
      scenario "I shouldn't be able to see a Us state drop down list" do
        within ".edit_store" do
          select('Sales Representative', from: 'Agent type')
          select('Colombia', from: 'Country')
        end
        find('.representative_serving').should_not be_visible
      end
    end
  end

  context "Creating a new store" do
    before do
      login_as_admin admin
      visit admin_stores_path
      click_on "New store"
      page.should have_content "New store"
    end

    context "As a Sales Representative in a US store" do
      before do
        within ".new_store" do
          select('Sales Representative', from: 'Agent type')
          select('United States', from: 'Country')
        end
        page.should have_content "Representative serving states"
      end

      scenario "I should be required to select at least one site/system" do
        click_on 'Create Store'
        page.should have_content "Systems enabled can't be blank"
      end

      scenario "I should be able to add more than one serving state" do
        check "store_systems_enabled_szus"
        fill_in 'Name', with: 'D-Store'
        select 'ellison', from: 'store_brands_'
        select 'Alabama', from: 'store_representative_serving_states_'
        select 'Arizona', from: 'store_representative_serving_states_'
        click_on 'Create Store'
        page.should have_content "Store was successfully created."
      end
    end

    context "As a Sales Representative not in a US store", js: true do
      scenario "I shouldn't be able to see a Us state drop down list" do
        within ".new_store" do
          select('Sales Representative', from: 'Agent type')
          select('Colombia', from: 'Country')
        end
        find('.representative_serving').should_not be_visible
      end
    end
  end

  context "filtering stores" do
    before do
      login_as_admin admin
      visit admin_stores_path
    end

    scenario "I should see the Agent type/Retailer type field" do
      page.should have_content "Agent type/Retailer type"
    end

    scenario "I should see the Catalog company field" do
      page.should have_content "Catalog Company"
    end

    scenario "I should be able to filter by Catalog Company" do
      store_without_catalog_company = FactoryGirl.create(:sales_representative_webstore_us_store)
      store_with_catalog_company = FactoryGirl.create(:store, catalog_company: true)

      visit current_path

      page.should have_content store_with_catalog_company.name
      page.should have_content store_without_catalog_company.name

      check 'catalog_company'
      click_on 'search'

      page.should have_content store_with_catalog_company.name
      page.should_not have_content store_without_catalog_company.name
    end

    Store::AGENT_TYPES.each do |agent_type|
      scenario "I should be able to filter by Agent type: #{agent_type}" do
        with_agent_type = FactoryGirl.create(:store, agent_type: agent_type)
        without_agent_type = FactoryGirl.create(:store)

        visit current_path

        select agent_type, from: 'agent_type'
        click_on 'search'

        page.should have_content with_agent_type.name
        page.should_not have_content without_agent_type.name unless agent_type == without_agent_type.agent_type
      end
    end
  end
end
