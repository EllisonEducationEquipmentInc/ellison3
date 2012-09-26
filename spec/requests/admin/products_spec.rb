require 'spec_helper'

feature "Products", js: true do
	let(:product_permission) { FactoryGirl.build(:permission, name: "products", write: true, systems_enabled: ["szus"]) }
	let(:admin){ FactoryGirl.create(:admin_user, password: "test1234", permissions: [product_permission]) }
	context "create product" do
  	scenario "as a admin I should be able to create a new product" do
  	  login_as_admin admin
  	  visit new_admin_product_path
  	  page.should have_content "New product"
  	  page.should have_content "System Visibility"
  	  page.should have_field("product_active_true", checked: true)
  	  check 'product_systems_enabled_szus'

  	  page.should have_content "Basic Information"
  	  fill_in "Product Name", with: "foo product"
  	  fill_in "Product Number", with: "123445"
  	  fill_in "Product UPC", with: "foo UPC"
  	  select 'bundle', from: 'Product Type'
  	  select 'Ellison', from: 'Brand'

  	  page.should have_content "Pricing & Availability"
  	  fill_in "MSRP USD", with: "12312"
  	  click_button "Create Product"
  	  page.should have_content "Product was successfully created."
  	end
  end

  context "edit product" do

    scenario "as a admin I should be able to sign in" do
      new_product = FactoryGirl.create(:product, created_by: admin.email, systems_enabled: ["szus"])

      login_as_admin admin
      visit admin_products_path
      page.should have_content "Listing products"
      page.should have_content new_product.name
      page.should have_content new_product.item_num

      click_link "Edit"
      page.should have_content "Edit product"

      fill_in "Product UPC", with: "foo UPC"
      fill_in "Wholesale Price USD", with: "9999"
      click_button "Update Product"
      page.should have_content "Product was successfully updated."
    end
  end
end