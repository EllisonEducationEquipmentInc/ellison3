# Be sure to restart your server when you modify this file.

#Rails.application.config.session_store :cookie_store, :key => '_ellison3_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# Rails.application.config.session_store :active_record_store

Ellison3::Application.config.session_store :mongoid_store, :key => '_ellison3_session', :expire_after => 30.days