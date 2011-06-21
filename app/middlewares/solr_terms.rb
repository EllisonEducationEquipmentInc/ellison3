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
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, [Net::HTTP.get(URI.parse("#{solr_path}/terms?terms.fl=spell&terms.prefix=#{URI.escape(term.downcase)}&terms.mincount=5&terms.sort=index&indent=true&wt=json&omitHeader=true&json.nl=arrarr"))]]
    elsif env["PATH_INFO"] =~ /^\/(#{ELLISON_SYSTEMS * '|'})_solr_terms\/(.+)$/
      term = $2
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, [Net::HTTP.get(URI.parse("#{solr_path}/terms?terms.fl=terms_#{$1}_text&terms.prefix=#{URI.escape(term.downcase)}&terms.mincount=5&terms.sort=index&indent=true&wt=json&omitHeader=true&json.nl=arrarr"))]]      
    elsif env["REQUEST_URI"] =~ /^\/products_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AProduct&fq=active_b%3Atrue&q=#{term.downcase.strip.gsub(/\+$/, '')}*&fl=id+item_num_ss+stored_name_ss+msrp_usd_fs+msrp_gbp_fs+msrp_eur_fs&qf=item_num_ss+stored_name_ss&start=0&rows=20&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Product ", ''), "label" => "#{e['item_num_ss']} - #{e['stored_name_ss']}", "value" => e['item_num_ss'], "msrp_usd" => e['msrp_usd_fs'], "msrp_gbp" => e['msrp_gbp_fs'], "msrp_eur" => e['msrp_eur_fs']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/ideas_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AIdea&fq=active_b%3Atrue&q=#{term.downcase.strip.gsub(/\+$/, '')}*&fl=id+idea_num_ss+stored_name_ss&qf=idea_num_ss+stored_name_ss&start=0&rows=20&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Idea ", ''), "label" => "#{e['idea_num_ss']} - #{e['stored_name_ss']}", "value" => e['idea_num_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/tags_autocomplete\?term=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3ATag&fq=active_b%3Atrue&q=#{term.downcase.strip.gsub(/\+$/, '')}*&fl=id+stored_name_ss+tag_type_ss+systems_enabled_sms&qf=stored_name_ss&start=0&rows=20&wt=ruby&omitHeader=true&json.nl=arrarr"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Tag ", ''), "label" => "#{e['stored_name_ss']} (#{e['tag_type_ss']}) #{e['systems_enabled_sms']}", "value" => e['stored_name_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/tags_by_type\?type=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3ATag&fq=active_b%3Atrue&fq=tag_type_ss%3A#{term}*&fl=id+stored_name_ss+tag_type_ss+systems_enabled_sms&qf=stored_name_ss&start=0&rows=300&wt=ruby&omitHeader=true&json.nl=arrarr&q=%2A%3A%2A&sort=stored_name_ss+asc"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Tag ", ''), "label" => "#{e['stored_name_ss']} (#{e['tag_type_ss']}) #{e['systems_enabled_sms']}", "value" => e['stored_name_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/get_products_by_tag\?id=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AProduct&fq=active_b%3Atrue&fq=tag_ids_sms%3A#{term}&fl=id+stored_name_ss+item_num_ss+systems_enabled_sms&start=0&rows=500&wt=ruby&omitHeader=true&json.nl=arrarr&q=%2A%3A%2A&sort=item_num_ss+asc"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Product ", ''), "label" => "#{e['item_num_ss']} - #{e['stored_name_ss']} #{e['systems_enabled_sms']}", "value" => e['stored_name_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/get_ideas_by_tag\?id=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AIdea&fq=active_b%3Atrue&fq=tag_ids_sms%3A#{term}&fl=id+stored_name_ss+idea_num_ss+systems_enabled_sms&start=0&rows=500&wt=ruby&omitHeader=true&json.nl=arrarr&q=%2A%3A%2A&sort=idea_num_ss+asc"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Idea ", ''), "label" => "#{e['idea_num_ss']} - #{e['stored_name_ss']} #{e['systems_enabled_sms']}", "value" => e['stored_name_ss']}}.to_json]
    elsif env["REQUEST_URI"] =~ /^\/product_helper_by_tag\?id=(.+)$/
      term = $1
      solr_response = Net::HTTP.get(URI.parse("#{solr_path}/select?fq=type%3AProduct&fq=active_b%3Atrue&fq=tag_ids_sms%3A#{term}&fl=id+stored_name_ss+item_num_ss+systems_enabled_sms+small_image_ss+tag_ids_sms&start=0&rows=500&wt=ruby&omitHeader=true&json.nl=arrarr&q=%2A%3A%2A&sort=item_num_ss+asc"))
      hash = eval(solr_response)
      [200, {"Content-Type" => 'text/plain; charset=utf-8'}, hash["response"]["docs"].inject([]) {|arr, e| arr << {"id" => e['id'].gsub("Product ", ''), "label" => "#{e['item_num_ss']} - #{e['stored_name_ss']} #{e['systems_enabled_sms']}", "value" => e['stored_name_ss'], "small_image" => e['small_image_ss'], "item_num" => e['item_num_ss'], "tag_ids" => e['tag_ids_sms']}}.to_json]
    else
      @app.call(env)
    end
  end
end