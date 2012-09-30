server 'qa.ellison.stackbuilders.com', :app, :web, :db, :utility, :primary => true

set :user, 'stackbuilders'
set :rails_env, 'qa'
set :branch, 'production'

set :deploy_to, "/var/projects/ellison/qa"
