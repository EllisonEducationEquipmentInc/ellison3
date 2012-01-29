require File.expand_path('../boot', __FILE__)
require 'image_science'
#require 'rails/all'
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "rails/test_unit/railtie"
require 'mongoid/railtie'
require 'rake'

# If you have a Gemfile, require the gems listed there, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env) if defined?(Bundler)

module Ellison3
  class Application < Rails::Application

    include Rake::DSL

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Add additional load paths for your own custom dirs
    # config.load_paths += %W( #{config.root}/extras )

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Pacific Time (US & Canada)' 

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    config.i18n.default_locale = 'en-US'

    # Configure generators values. Many other options are available, be sure to check the documentation.
    config.generators do |g|
      g.orm             :mongoid
      g.template_engine :haml
      #g.test_framework  :shoulda
			#g.fallbacks[:shoulda] = :rspec 
      g.test_framework  :rspec
			g.fixture_replacement :factory_girl_rails
    end

		config.autoload_paths << File.join(Rails.root, "app", "uploaders")
		
    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"
        
    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password, :password_confirmation, :full_card_number, :card_security_code]
      	
    config.action_mailer.default :charset => "utf-8"
    
    config.middleware.insert_before Rack::Runtime, "FitterHappier"
    config.middleware.insert_before Rack::Runtime, "SolrTerms" 
    config.middleware.insert_before Rack::Runtime, "Gridfs"
    config.middleware.insert_after ActionDispatch::Flash, "DynamicCache"
    
    config.gem 'rack-recaptcha', :lib => 'rack/recaptcha'
    config.middleware.use Rack::Recaptcha, :public_key => '6LccaAQAAAAAAOK5d5-hmN0uuXuJtcDdSjzfUiCS', :private_key => '6LccaAQAAAAAACmi40-3YDKa0pfGYp8QO4oaRdej'

  end
end
