module EnvironmentHelpers
  def set_request_host host
    ActionDispatch::Request.any_instance.stub(:host).and_return host
  end
end

RSpec.configure do |config|
  config.include EnvironmentHelpers, type: :request
  config.include EnvironmentHelpers, type: :controller
end
