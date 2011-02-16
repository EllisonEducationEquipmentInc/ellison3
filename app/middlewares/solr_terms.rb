require 'sunspot'
require 'net/http'
require 'uri'

class SolrTerms
  
  def initialize(app)  
    @app = app  
  end
  
  def call(env)
    solr_path = "http://#{Sunspot::Rails.configuration.hostname}:#{Sunspot::Rails.configuration.port}#{Sunspot::Rails.configuration.path}"
    if env["PATH_INFO"] =~ /^\/solr_terms\/(.+)$/
      term = $1
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, [Net::HTTP.get(URI.parse("#{solr_path}/terms?terms.fl=spell&terms.prefix=#{URI.escape(term)}&terms.mincount=5&terms.sort=index&indent=true&wt=json&omitHeader=true&json.nl=arrarr"))]]
    else
      @app.call(env)
    end
  rescue Exception => e
    [500, {"Content-Type" => 'text/plain; charset=utf-8'}, [e.to_s]]
  end
end