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
        begin
          Event.count
          [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site and Database Check Passed @ #{time}\n"]]
        rescue Mongo::ConnectionFailure => e
          [500, {"Content-Type" => 'text/html; charset=utf-8'}, ["!!! ALERT !!! MONGODB IS DOWN!!! @ #{time}\n"]]
        rescue Exception => e
          [500, {"Content-Type" => 'text/html; charset=utf-8'}, ["!!! ALERT !!! INTERNAL SERVER ERROR!!! @ #{time}\n#{e}"]]
        end
      when "/site_solr_and_database_check"
        begin
          resp = Net::HTTP.get(URI.parse("http://#{Sunspot::Rails.configuration.hostname}:#{Sunspot::Rails.configuration.port}#{Sunspot::Rails.configuration.path}/terms?terms.fl=spell&terms.prefix=sizz&terms.mincount=5&terms.sort=index&indent=true&wt=json&omitHeader=true&json.nl=arrarr"))
          Event.count
          [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site, Solr and Database Check Passed @ #{time}\n"]]
        rescue Errno::ECONNREFUSED => e
          [500, {"Content-Type" => 'text/html; charset=utf-8'}, ["!!! ALERT !!! SOLR IS DOWN!!! @ #{time}\n"]]
        rescue Mongo::ConnectionFailure => e
          [500, {"Content-Type" => 'text/html; charset=utf-8'}, ["!!! ALERT !!! MONGODB IS DOWN!!! @ #{time}\n"]]
        rescue Exception => e
          [500, {"Content-Type" => 'text/html; charset=utf-8'}, ["!!! ALERT !!! INTERNAL SERVER ERROR!!! @ #{time}\n#{e}"]]
        end        
      else
        [200, {"Content-Type" => 'text/html; charset=utf-8'}, ["FitterHappier Site Check Passed"]]
      end
    else
      @app.call(env)
    end
  end
end