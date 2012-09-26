module Devise::CapybaraTestHelpers
  def login_as_admin(admin)
    visit admin_path

    within("#admin_new") do
      fill_in("admin_email", with: admin.email)
      fill_in("admin_password", with: admin.password)

      click_button("Sign in")
    end
  end
end

RSpec.configure do |config|
  config.include Devise::CapybaraTestHelpers, type: :request
end