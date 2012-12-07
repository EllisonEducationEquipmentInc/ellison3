namespace :maintenance do
  
  desc "delete old sessions"
  task :cleanup_sessions => :environment do
    ActionDispatch::Session::MongoidStore::Session.where(:updated_at.lt => 30.days.ago).delete_all
  end

  desc "index sessions"
  task :index_sessions => [:environment] do
    p ActionDispatch::Session::MongoidStore::Session.create_indexes
  end
end
