# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= 'test'
require File.expand_path("../../config/environment", __FILE__)
require 'rspec/rails'
require 'rspec/autorun'
require 'capybara/rspec'
require 'shoulda/matchers'
require 'database_cleaner'
require 'webmock'

WebMock.disable_net_connect!(:allow_localhost => true)

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[Rails.root.join("spec/support/**/*.rb")].each {|f| require f}

if ENV["SELENIUM"]
  Capybara.javascript_driver = :selenium
else
  Capybara.javascript_driver = :webkit
end

RSpec.configure do |config|
  # If true, the base class of anonymous controllers will be inferred
  # automatically. This will be the default behavior in future versions of
  # rspec-rails.
  config.include Mongoid::Matchers
  config.infer_base_class_for_anonymous_controllers = false
  config.order = "random"
  config.mock_with :rspec

  config.before :suite do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.orm = "mongoid"
  end

  config.before :each do
    DatabaseCleaner.start

    Geokit::Geocoders::MultiGeocoder.stub(:geocode).
      and_return(double('as response', success: true, lat: 37.3203455, lng: -122.0328205))
  end

  config.after :each do
    DatabaseCleaner.clean
  end
end
