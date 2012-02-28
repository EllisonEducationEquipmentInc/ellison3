namespace :maintenance do
  
  desc "delete old sessions"
  task :cleanup_sessions => :environment do
    ActionDispatch::Session::MongoidStore::Session.where(:updated_at.lt => 30.days.ago).delete_all
  end
end
