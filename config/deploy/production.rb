server 'qa.ellison.stackbuilders.com', :app, :web, :db, :utility, :primary => true

set :user, 'ellison'
set :rails_env, 'production'
set :branch, 'production'
set :deploy_to, "/data/ellison3_production"

set :deploy_to, "/var/projects/ellison/qa"
