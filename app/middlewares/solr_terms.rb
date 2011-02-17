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
    elsif env["REQUEST_URI"] =~ /^\/products_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AProduct&fq=active_b%3Atrue&q=#{term.strip.gsub(/\+$/, '')}*&fl=id+item_num_ss+stored_name_ss+msrp_usd_f&qf=item_num_ss+stored_name_ss&start=0&rows=10&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Product ", ''), "label" => "#{e['item_num_ss']} - #{e['stored_name_ss']}", "value" => e['item_num_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/ideas_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AIdea&fq=active_b%3Atrue&q=#{term.strip.gsub(/\+$/, '')}*&fl=id+idea_num_ss+stored_name_ss&qf=idea_num_ss+stored_name_ss&start=0&rows=10&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Idea ", ''), "label" => "#{e['idea_num_ss']} - #{e['stored_name_ss']}", "value" => e['idea_num_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/tags_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3ATag&fq=active_b%3Atrue&q=#{term.strip.gsub(/\+$/, '')}*&fl=id+stored_name_ss+tag_type_ss&qf=stored_name_ss&start=0&rows=10&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Tag ", ''), "label" => "#{e['stored_name_ss']} (#{e['tag_type_ss']})", "value" => e['stored_name_ss']}}.to_json]
    else
      @app.call(env)
    end
  rescue Exception => e
    [500, {"Content-Type" => 'text/plain; charset=utf-8'}, [e.to_s]]
  end
end