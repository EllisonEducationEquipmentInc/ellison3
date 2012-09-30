server 'staging.ellison.stackbuilders.com', :app, :web, :db, :utility, :primary => true

set :user, 'stackbuilders'
set :rails_env, 'staging'

set :deploy_to, "/var/projects/ellison/staging"
