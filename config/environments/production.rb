require File.join(File.dirname(__FILE__), '../memcached') #load memcached port from memcached.rb

Ellison3::Application.configure do
  # Settings specified here will take precedence over those in config/environment.rb

  # The production environment is meant for finished, "live" apps.
  # Code is not reloaded between requests
  config.cache_classes = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # For nginx:
  config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect'

  # If you have no front-end server that supports something like X-Sendfile,
  # just comment this out and Rails will serve the files

  # See everything in the log (default is :info)
  # config.log_level = :debug

  # Use a different logger for distributed setups
  # config.logger = SyslogLogger.new

  # Use a different cache store in production
  # config.cache_store = :mem_cache_store
  config.cache_store = :mem_cache_store, "localhost:#{ENV['memcached_port']}", {:namespace => 'ellison3', :compress => true}

  # Disable Rails's static asset server
  # In production, Apache or nginx will already do this
  config.serve_static_assets = false

  # Enable serving of images, stylesheets, and javascripts from an asset server
  # config.action_controller.asset_host = Proc.new { |source, request|
  #     if request.ssl?
  #       "#{request.protocol}#{request.host_with_port}"
  #     else
  #       "http://asset#{rand(9)+1}.#{get_domain}"
  #     end
  #   }

  # Disable delivery errors, bad email addresses will be ignored
  # config.action_mailer.raise_delivery_errors = false
	config.action_mailer.default_url_options = { :host => 'ellison.com' }
	config.action_mailer.delivery_method = :smtp
	ey_smtp_settings = {
    :domain             => "sizzix.com", 
    :address            => "smtp",
    :port               => 25,
    :perform_deliveries => true
  }
  config.action_mailer.smtp_settings = ey_smtp_settings #{:address => "mail.ellison.com", :port => 25} 
  #config.action_mailer.smtp_settings = {:address => "mail.ellison.com", :port => 25} 
	config.action_mailer.perform_deliveries = true
	config.action_mailer.raise_delivery_errors = false

  # Enable threaded mode
  config.threadsafe!
  
  config.dependency_loading = true if $rails_rake_task

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true
  
  config.active_support.deprecation = :notify
end
