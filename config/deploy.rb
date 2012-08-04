$:.unshift(File.expand_path('./lib', ENV['rvm_path'])) # Add RVM's lib directory to the load path.
require "rvm/capistrano"                  # Load RVM's capistrano plugin.
set :rvm_ruby_string, 'ruby-1.9.2-p136@global'

require "bundler/capistrano"
#require "eycap/recipes"

#=================================================================================================
# ELLISON CUSTOM CONDITIONS
#=================================================================================================
# optional ENV variables to specify what svn repo should be deplyed
#
# usage example:
# 
# cap staging deploy TAG="version_1.0"
# cap staging deploy - (new command to deploy from git) deploys from staging branch always
 
#if ENV['TAG']
#  deploy_version = "tags/#{ENV['TAG']}"
#elsif ENV['BRANCH']
#  deploy_version = "branches/#{ENV['BRANCH']}"
#else
#  deploy_version = "trunk/"
#end
set :keep_releases,       5
set :application,         "ellison3"
set :user,                "ellison"
set :password,            "ellison123" #"RbBR5VrQ"
set :deploy_to,           "/data/ellison3_production" #"/data/ellison3_qa"
set :monit_group,         "ellison"
set :runner,              "ellison"
#set :scm_username,       "engineyard"
#set :scm_password,        "yardwork123"
#set :scm_passphrase,      ""
set :scm,                 :git
set :branch,              "staging"
set :repository,          "git@github.com:ellisoneducation/ellison3.git"
set :deploy_via,          :remote_cache
set :repository_cache,    "/var/cache/engineyard/#{application}"
set :production_database, "ellison3_production"
set :production_dbhost,   "localhost"
set :staging_database,    "ellison3_production"
set :staging_dbhost,      "localhost"
set :dbuser,              "ellison"
set :dbpass,              "Yh4XS3Sy"

set :delayed_script_path, "#{current_path}/script/delayed_job"
set :delayed_job_role, :app
set :base_ruby_path, '/usr/local'

default_run_options[:pty] = true 

# comment out if it gives you trouble. newest net/ssh needs this set.
ssh_options[:paranoid] = false

require 'cap_recipes/tasks/utilities'

# =================================================================================================
# ROLES
# =================================================================================================
# You can define any number of roles, each of which contains any number of machines. Roles might
# include such things as :web, or :app, or :db, defining what the purpose of each machine is. You
# can also specify options that can be used to single out a specific subset of boxes in a
# particular role, like :primary => true.

task :production do

  role :web, "192.168.2.171"
  role :app, "192.168.2.171", :memcached => true
  role :db , "192.168.2.171", :primary => true
  role :app, "192.168.2.171", :no_release => true, :no_symlink => true, :memcached => true

  set :rails_env, "production"
  set :delayed_job_env, 'production'
  
  set :environment_database, defer { production_database }
  set :environment_dbhost, defer { production_dbhost }

  after "custom_symlink", "prod_symlink"
  after "prod_symlink", "custom_migrations"
end

task :staging do

  role :web, "192.168.2.171"
  role :app, "192.168.2.171", :memcached => true
  role :db , "192.168.2.171", :primary => true
  role :app, "192.168.2.171", :no_release => true, :no_symlink => true, :memcached => true

  set :rails_env, "staging"
  set :delayed_job_env, 'staging'
  
  set :environment_database, defer { staging_database }
  set :environment_dbhost, defer { staging_database }

  after "custom_symlink", "prod_symlink"
  after "prod_symlink", "custom_migrations"
end

desc "Application symlinks"
task :custom_symlink, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
   run "ln -nfs #{shared_path}/images/ #{release_path}/public/images"
   run "ln -nfs #{shared_path}/config/newrelic.yml #{latest_release}/config/newrelic.yml"
   run "ln -nfs #{shared_path}/config/mongoid.yml #{latest_release}/config/mongoid.yml"
   run "ln -nfs #{shared_path}/config/memcached.rb #{latest_release}/config/memcached.rb"
end

task :prod_symlink, :roles => :app, :except => {:no_release => true, :no_symlink => true} do
   run "ln -nfs #{shared_path}/config/sunspot.yml #{latest_release}/config/sunspot.yml"
   #run "cd #{latest_release} && RAILS_ENV=production ./script/delayed_job stop"
   #run "cd #{latest_release} && RAILS_ENV=production ./script/delayed_job start"
end

desc "incremental custom migrations"
task :custom_migrations, :roles => :db, :except => {:no_release => true} do
  run "cd #{latest_release} && RAILS_ENV=#{rails_env} bundle exec rake migrations:run"
end

#after "deploy:symlink_configs", "custom_symlink"
after "deploy:start",   "delayed_job:start"
after "deploy:stop",    "delayed_job:stop"
after "deploy:restart", "delayed_job:restart"

# Do not change below unless you know what you are doing!
after "deploy", "deploy:cleanup"
after "deploy:migrations" , "deploy:cleanup"
#after "deploy:update_code", "deploy:symlink_configs"
after "deploy:update_code", "custom_symlink"
#after 'custom_symlink', 'bundler:bundle_new_release'

# uncomment the following to have a database backup done before every migration
# before "deploy:migrate", "db:dump"

namespace :memcached do
  desc "Flush memcached - this assumes memcached is on port 11212"
  task :flush, :roles => [:app], :only => {:memcached => true} do
    sudo "echo 'flush_all' | nc localhost 11212 -q 1"
  end
end


# if you're still using the script/reaper helper you will need
# these http://github.com/rails/irs_process_scripts

# If you are using Passenger mod_rails uncomment this:
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "touch #{File.join(current_path,'tmp','restart.txt')}"
  end
end


namespace :bundler do
  task :create_symlink, :roles => :app do
    shared_dir = File.join(shared_path, 'bundle')
    release_dir = File.join(latest_release, '.bundle')
    run("mkdir -p #{shared_dir} && ln -s #{shared_dir} #{release_dir}")
  end
 
  task :bundle_new_release, :roles => :app do
    bundler.create_symlink
    run "cd #{release_path} && bundle install --without test development"
  end
end

namespace :delayed_job do
  desc "Start delayed_job process"
  task :start, :roles => delayed_job_role do
    utilities.with_role(delayed_job_role) do
      run "RAILS_ENV=#{delayed_job_env} #{base_ruby_path}/bin/ruby #{delayed_script_path} start"
    end
  end

  desc "Stop delayed_job process"
  task :stop, :roles => delayed_job_role do
    utilities.with_role(delayed_job_role) do
      run "RAILS_ENV=#{delayed_job_env} #{base_ruby_path}/bin/ruby #{delayed_script_path} stop"
    end
  end

  desc "Restart delayed_job process"
  task :restart, :roles => delayed_job_role do
    utilities.with_role(delayed_job_role) do
      delayed_job.stop
      sleep(4)
      #run "killall -s TERM delayed_job; true"
      enforce_stop_delayed_job
      delayed_job.start
    end
  end
  
  def enforce_stop_delayed_job
    run %Q{
      lsof '#{current_path}/log/delayed_job.log' | awk '/^ruby/ { system("kill " $2) }' ;
      COUNT=1;
      until [ $COUNT -eq 0 ]; do
        COUNT=`lsof '#{current_path}/log/delayed_job.log' | grep '^ruby' |wc -l` ;
        echo 'waiting for delayed_job to end' ;
        sleep 2 ;
      done
    }.split("\n").join('')
  end
end
        require './config/boot'
        require 'airbrake/capistrano'
