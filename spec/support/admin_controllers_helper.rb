module AdminControllersHelpers
  
  def stub_admin_acccess!
    controller.stub :get_system
    controller.stub :admin_read_permissions!
  end
end

RSpec.configure do |config|
  config.include AdminControllersHelpers, type: :controller
end
