module Saia
  require 'rubygems'
  require 'builder'
  require "uri"
  require 'net/http'
  require 'cgi'
  require 'rexml/document'
  require 'rexml/formatters/pretty'
  
  class SaiaError < StandardError; end #:nodoc:
  
  class Rate
    attr_accessor :total_invoice, :quote_number, :expiration_date, :estimated_delivery_date, :standard_service_days
  end
  
  class Saia
    
    attr_accessor :user_id, :password, :account_number, :test, :billing_terms, :destination_city, :destination_state, :destination_zip_code, :weight, :class_code, :accessorial_code, :response, :raw_response
    
    # @saia = Saia.new :user_id => YOUR_USER_ID, :password => YOUR_PASSWORD
    def initialize(attributes)
      attributes.each { |k, v| send(:"#{k}=", v)}
      raise SaiaError, "You must set :user_id and :password" if user_id.nil? || password.nil?
    end
    
    def rate
      send_request(build_create)
      if @response.root.elements['Fault'].text.blank?
        r = Rate.new
        r.total_invoice = @response.root.elements['TotalInvoice'].text
        r.quote_number = @response.root.elements['QuoteNumber'].text
        r.expiration_date = @response.root.elements['ExpirationDate'].text
        r.estimated_delivery_date = @response.root.elements['EstimatedDeliveryDate'].text
        r.standard_service_days = @response.root.elements['StandardServiceDays'].text        
        r
      else
        raise SaiaError, @response.root.elements['Message'].text
      end
    end
    
    def test
      @test || false
    end
  
  private
  
    def send_request(xml)
      url = URI.parse("http://www.saiasecure.com/webservice/ratequote/xml.aspx")
      request = Net::HTTP::Post.new(url.path, initheader = {'Content-Type' =>'text/xml'})
  		http = Net::HTTP.new(url.host, url.port)
  		timeout(50) do
    		#http.use_ssl = true
    		http.start do |http|
    			request.body = xml
    			@raw_response = http.request(request)
    			@response = REXML::Document.new @raw_response.body
    		end
    	end
    end
    
    def build_create
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct!
      xml.Create do 
        xml.UserID user_id
        xml.Password password
        xml.TestMode test ? "Y" : "N"
        xml.BillingTerms(billing_terms || "Prepaid")
        xml.AccountNumber account_number
        xml.Application "Outbound"
        xml.DestinationCity destination_city
        xml.DestinationState destination_state
        xml.DestinationZipcode destination_zip_code
        xml.Details do
          xml.DetailItem do
            xml.Weight weight
            xml.Class(class_code || 70)
          end
        end
        xml.Accessorials do
          xml.AccessorialItem do
            xml.Code(accessorial_code || "SingleShipment")
          end
        end
      end
      xml.target!
    end
    
  end
end