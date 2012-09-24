ENV['PATH'] = "/usr/local/bin:#{ENV['PATH']}"
source 'http://rubygems.org'
source 'http://gemcutter.org'
source 'http://gems.github.com'
require 'rubygems'
require 'csv'

gem 'bundler', '>=1.0.10'
gem 'rails', '3.0.4'
gem 'mongo_ext'
gem "bson_ext", "~> 1.5.2"
gem 'passenger'
gem 'mysql'
gem 'haml', '3.1.2'
gem 'sass'
gem 'will_paginate', '3.0.3'
gem "mongo_session_store-rails3"
gem "mongoid", "2.0.1"
gem "nifty-generators"
gem "compass", "0.11.5"
gem 'RubyInline'
gem 'image_science', git: 'git://github.com/asynchrony/image_science.git'
gem 'carrierwave', '0.5.3'
gem 'remotipart', '0.4.1'
gem 'hpricot'
gem 'ruby_parser'
gem 'devise', '1.1.3'
gem 'warden'
gem 'activemerchant', :require => 'active_merchant'
gem 'httparty'
gem 'shippinglogic', :git => 'git://github.com/computadude/shippinglogic.git', :branch => "master"
gem 'sunspot_mongoid', :git => 'git://github.com/jugyo/sunspot_mongoid.git', :branch => "master"
gem 'feedzirra'
gem 'geokit'
gem 'youtube_it'
gem 'memcache-client'
gem 'event-calendar', :require => 'event_calendar', :git => 'git://github.com/elevation/event_calendar.git', :branch => "master"
gem "ghazel-daemons"
gem 'delayed_job', '3.0.3'
gem 'delayed_job_mongoid'
gem 'rack-recaptcha', :require => 'rack/recaptcha'
gem 'barista'
gem 'execjs'
gem 'therubyracer'
gem 'sunspot-rails-failover', :git => 'git://github.com/flyingmachine/sunspot-rails-failover.git'
gem 'savon'
gem "airbrake"
gem 'capistrano'


group :test do
  gem 'shoulda-matchers'
  gem 'capybara'
  gem 'capybara-webkit'
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'launchy'
end

group :development, :test do
  gem 'rspec-rails', '~> 2.11.0'
end

gem "rails3-generators", :group => :development 
group :development do
  gem "ruby-debug19"
  gem "rack-bug"
  gem 'wirble'
end
