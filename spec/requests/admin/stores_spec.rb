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

    scenario "as a admin I should be able to check in which systems a store can be display" do
      systems_enabled.each do |system|
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
      scenario "I should be able to see a Us state drop down list" do
        within ".new_store" do
          select('Sales Representative', from: 'Agent type')
          select('United States', from: 'Country')
        end
        page.should have_content "Representative serving states"
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
end
