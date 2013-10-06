require 'nokogiri'
require 'open-uri'
require 'builder'
require 'base64'
require 'active_support/inflector'
require 'active_support/core_ext/hash'
require 'active_support/inflector'

class Lyrishq
  attr_accessor :ml_id, :site_id, :password, :activity, :type, :email, :request, :response, :demographics, :extras

  # Example:
  #
  # l=Lyrishq.new ml_id: '1742', site_id: '2012000352', type: 'record', activity: 'query-data', email: 'mronai@ellison.com'
  # l.success? => false
  # l.error #=> "Can't find email address or unique id"
  #
  # add email:
  # l=Lyrishq.new ml_id: '1742', site_id: '2012000352', type: 'record', activity: 'add', email: 'mronai@ellison.com'
  #
  # update:
  # l=Lyrishq.new ml_id: '1742', site_id: '2012000352', type: 'record', activity: 'update', email: 'mronai@ellison.com', demograpics: {1 => "john", 2 => "smith"}
  def initialize(options = {})
    @ml_id = options[:ml_id]
    @site_id = options[:site_id]
    @email = options[:email]
    @password = options[:password] || LYRIS_HQ_PASSWORD
    @activity = options[:activity] || 'query'
    @type = options[:type] || 'demographic'
    @demographics = options[:demographics] || {}
    @extras = options[:extras] || {}
    process
  end

  def params
    {activity: @activity, type: @type, input: @request}
  end

  def process
    uri = URI('https://www.elabs12.com/API/mailing_list.html')
    build_query_data_request(email)
    uri.query = URI.encode_www_form(params)
    @response = Nokogiri::HTML(open(uri))
  end

  def success?
    @response && (@response/"type").present? && (@response/"type").inner_text == 'success'
  end

  def error?
    !success?
  end

  def error
    (@response/"data").inner_text if error? && @response.present?
  end

  def uid
    extra(:uid)
  end

  def extra(id)
    response.xpath("//data[@id='#{id}' and @type='extra']").inner_text if success?
  end

  def demographic(id)
    response.xpath("//data[@id='#{id}' and @type='demographic']").inner_text if success?
  end

private

  # ACTIVITY: QUERY-DATA
  def build_query_data_request(email)
    xml = Builder::XmlMarkup.new :indent => 2
    xml.DATA email, 'type' => "email" if email
    demographics.each do |id, value|
      xml.DATA value, 'type' => "demographic", 'id' => id
    end
    extras.each do |id, value|
      xml.DATA value, 'type' => "extra", 'id' => id
    end
    @request = build_request xml.target!
  end

  def build_request(body)
    xml = Builder::XmlMarkup.new :indent => 2
    #xml.instruct!
    xml.DATASET do
      xml.SITE_ID @site_id
      xml.MLID @ml_id
      xml.DATA @password, 'type' => 'extra', 'id' => 'password'
      xml << body
    end
    xml.target!
  end
end
