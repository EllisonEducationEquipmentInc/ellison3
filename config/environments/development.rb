Ellison3::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = true

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false
  config.active_support.deprecation = :log
  
  # A dummy setup for development - no deliveries, but logged
  config.action_mailer.delivery_method = :smtp  
  config.action_mailer.smtp_settings   = {:address => "lfexch02.ellison.com", :port => 25}
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = false
  
  config.cache_store = :mem_cache_store, 'localhost:11211', {:namespace => 'ellison3', :compress => true}
  
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  config.action_mailer.delivery_method = :letter_opener
  
  config.after_initialize do
    SslRequirement.disable_ssl_check = true
    Mongoid.database.connection.instance_variable_set "@logger", Mongoid::Logger.new unless Mongoid.database.connection.logger
  end
  
end
