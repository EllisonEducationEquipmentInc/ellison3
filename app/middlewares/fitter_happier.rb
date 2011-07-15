# custom FitterHappier rack app to check app's healthiness (including mongodb)
class FitterHappier
  def initialize(app)  
    @app = app  
  end
  
  def call(env)
    if env["PATH_INFO"] =~  /^\/fitter_happier(.+)?$/
      time = Time.now.to_formatted_s(:rfc822)
      case $1
      when "/site_check"
        [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site Check Passed @ #{time}\n"]]
      when "/site_and_database_check"
        [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site and Database Check Passed @ #{time}\nDatabase: #{Digest::SHA1.hexdigest(Mongoid.database.name)}\n"]]
      else
        [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site Check Passed"]]
      end
    else
      @app.call(env)
    end
  end
end