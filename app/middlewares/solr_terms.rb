require 'sunspot'
require 'net/http'

class SolrTerms
  
  def initialize(app)  
    @app = app  
  end
  
  def call(env)
    if env["PATH_INFO"] =~ /^\/solr_terms\/(.+)$/
      term = $1
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, [Net::HTTP.get(URI.parse("http://#{Sunspot::Rails.configuration.hostname}:#{Sunspot::Rails.configuration.port}#{Sunspot::Rails.configuration.path}/terms?terms.fl=spell&terms.prefix=#{term}&terms.sort=index&indent=true&wt=json&omitHeader=true"))]]
    else
      @app.call(env)
    end
  end
end