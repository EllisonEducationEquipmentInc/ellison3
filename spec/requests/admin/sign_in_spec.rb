require 'spec_helper'

feature "Sign In" do
  let(:admin){ FactoryGirl.create(:admin_user, password: "test1234") }

  scenario "as a admin I should be able to sign in" do
    login_as_admin admin
    page.should have_content "Signed in successfully."
    page.should have_content "this is the main admin page"
  end
end