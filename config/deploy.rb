require 'bundler/capistrano'
require 'capistrano/ext/multistage'
require 'airbrake/capistrano'
require "delayed/recipes"

set :rvm_ruby_string, 'ruby-1.9.3-p194@Ellison3'
require "rvm/capistrano"                  # Load RVM's capistrano plugin.

set :use_sudo, false

set :keep_releases,       5
set :application,         "ellison3"

set :scm,                 :git
set :branch,              "master"
set :repository,          "git@github.com:stackbuilders/ellison3.git"

set :default_stage, "staging"

set :deploy_via,          :remote_cache


before "deploy:restart", "delayed_job:stop"
after  "deploy:restart", "delayed_job:start"
after "deploy:stop",  "delayed_job:stop"
after "deploy:start", "delayed_job:start"


desc "Application symlinks"
task :custom_symlink, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
   run "ln -nfs #{shared_path}/images/ #{release_path}/public/images"
   run "ln -nfs #{shared_path}/config/newrelic.yml #{latest_release}/config/newrelic.yml"
   run "ln -nfs #{shared_path}/config/mongoid.yml #{latest_release}/config/mongoid.yml"
   run "ln -nfs #{shared_path}/config/memcached.rb #{latest_release}/config/memcached.rb"
   run "ln -nfs #{shared_path}/config/sunspot.yml #{latest_release}/config/sunspot.yml"
end

desc "incremental custom migrations"
task :custom_migrations, :roles => :db, :except => {:no_release => true} do
  run "cd #{latest_release} && RAILS_ENV=#{rails_env} bundle exec rake migrations:run"
end

after "deploy:start",   "delayed_job:start"
after "deploy:stop",    "delayed_job:stop"
after "deploy:restart", "delayed_job:restart"

after "deploy", "deploy:cleanup"
after "deploy:migrations" , "deploy:cleanup"
after "deploy:update_code", "custom_symlink"


namespace :memcached do
  desc "Flush memcached - this assumes memcached is on port 11212"
  task :flush, :roles => [:app], :only => {:memcached => true} do
    sudo "echo 'flush_all' | nc localhost 11212 -q 1"
  end
end
