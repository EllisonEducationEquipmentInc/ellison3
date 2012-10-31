server '192.168.2.171', :app, :web, :db, :utility, :primary => true

set :user,                "ellison"
set :password,            "ellison123"

set :rails_env, 'staging'
set :deploy_to, "/data/ellison3_production"
set :repository, "git@github.com:ellisoneducation/ellison3.git"
set :deploy_to, "/data/ellison3_production"
