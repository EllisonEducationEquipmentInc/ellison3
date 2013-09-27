require 'net/http'
require 'net/https'
require 'builder'
require 'base64'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'active_support/inflector'
require 'active_support/core_ext/hash'
require 'active_support/inflector'

class Lyrishq
  attr_accessor :ml_id, :site_id, :password, :action, :request, :response

  def initialize(options = {})
    @ml_id = options[:ml_id]
    @site_id = options[:site_id]
    @password = options[:password]
    @action = options[:action]
  end

private

  # ACTIVITY: QUERY-DATA
  def build_query_data_request(email)
    xml = Builder::XmlMarkup.new :indent => 2
    xml.DATA email, 'type' => "email"
    @request = build_request xml.target!
  end

  def build_request(body)
    xml = Builder::XmlMarkup.new :indent => 2
    xml.instruct!
    xml.DATASET do
      xml.SITE_ID @site_id
      xml.MLID @ml_id
      xml.DATA @password, 'type' => 'extra', 'id' => 'password'
      xml << body
    end
    xml.target!
  end
end
