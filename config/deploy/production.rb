role :web, "209.251.187.165:7000"
role :db , "209.251.187.165:7000", :primary => true

role :app, "209.251.187.165:7000", :memcached => true
role :app, "209.251.187.165:7001", :memcached => true
role :app, "209.251.187.165:7002", :memcached => true

set :user,                "ellison"

set :rails_env, 'production'
set :repository, "git@github.com:ellisoneducation/ellison3.git"
set :deploy_to, "/data/ellison3"
