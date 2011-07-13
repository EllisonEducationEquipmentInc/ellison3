module CCH
  require 'rubygems'
  require 'builder'
  require "uri"
  require 'net/http'
  require 'cgi'
  require 'rexml/document'
  require 'rexml/formatters/pretty'
	#require 'system_timer'
    
  if Rails.env == 'production'
    SERIAL_NUMBER = '7400-9802-FFEC-9187' #LIVE
  else
    SERIAL_NUMBER = '7404-7806-FFD8-F807'
  end
  
  NEXUS = "POD"
  
  class Cch
        
    attr_accessor :cart
    attr_accessor :items
    attr_accessor :total
    attr_accessor :customer
    attr_accessor :shipping_charge
    attr_accessor :handling_charge
    attr_accessor :request
    attr_accessor :response
    attr_accessor :total_tax
    attr_accessor :transaction_id
    attr_accessor :exempt
    attr_accessor :referred_id
    attr_accessor :merchant_transaction_id
    attr_accessor :tax_exempt_certificate
    
    @@times_sent = 0
    
    def initialize(attributes)
      @cart = attributes[:cart]                         # cart object
      @items = @cart ? @cart.cart_items : attributes[:items]               # cart_item, or order_item object
      @total = @cart ? @cart.taxable_amaunt : attributes[:total]  # order subtotal
      @customer = attributes[:customer]                 # Address object
      @shipping_charge = attributes[:shipping_charge]   # decimal
      @handling_charge = attributes[:handling_charge]   # decimal
      @transaction_id = attributes[:transaction_id]
      @exempt = attributes[:exempt] || false            # tax exempt: boolean
      @referred_id = attributes[:referred_id] 
      @tax_exempt_certificate = attributes[:tax_exempt_certificate].present? ? attributes[:tax_exempt_certificate] : "Unknown"
      @merchant_transaction_id = attributes[:merchant_transaction_id] || order_prefix
			@confirm_address = attributes[:confirm_address].nil? ? false : attributes[:confirm_address]
      if  (attributes[:action] == 'ProcessAttributedReturn' || attributes[:action] == 'calculate_ds')# && !@items.blank? 
        attributes[:action] == 'ProcessAttributedReturn' ? process_attributed_return : calculate_ds
      elsif attributes[:action] == 'calculate'
        calculate
      elsif attributes[:action] == 'commit' && @transaction_id
        commit
      else
        raise CchError, "Pass a Cart or Order object that contains at least one cart item for calculate_ds action, Or pass :action => 'commit', :transaction_id => '8125546044473500'  if you want to commit a previous transaction"
      end
    end

    def calculate_ds
      send_request('Calculate_DS')
      @@times_sent += 1
      Rails.logger.info "*** cch calculate_ds sent #{@@times_sent} times" 
      correct_address
    end
    
    def calculate
      send_request('Calculate')
      correct_address
    end
    
    def process_attributed_return_ds
      send_request 'ProcessAttributedReturn_DS'
    end
    
    def process_attributed_return
      send_request 'ProcessAttributedReturn'
    end
    
    def commit
      send_request('Commit')
      @@times_sent += 1
      Rails.logger.info "*** cch commit sent #{@@times_sent} times"
    end
        
    def pretty(rexml = :response)
      # returns a nicely formtted (indented, with line breaks) xml
      # rexml values: :response, :request, :transaction_xml, :corrected_address_xml
      bar = REXML::Formatters::Pretty.new
      out = String.new
      bar.write(send(rexml).is_a?(String) ? REXML::Document.new(send(rexml)) : send(rexml), out)
      out
    end
    
    def transaction_xml
      @response.root.elements['soap:Body'].elements['types:TaxTransaction']
    end
    
    def corrected_address_xml
      @response.root.elements['soap:Body'].elements['types:CorrectedAddress']
    end
    
    def transaction_id
      transaction_xml.elements['CertiTAXTransactionId'].text
    end
    
    def total_tax
      BigDecimal.new transaction_xml.elements['TotalTax'].text
    end
    
    def correct_address
			return unless @confirm_address
      begin
        @customer.city = corrected_address_xml.elements['City'].text
        @customer.zip_code = corrected_address_xml.elements['PostalCode'].text
        @customer.state = corrected_address_xml.elements['State'].text
        @customer.address1 = corrected_address_xml.elements['Street1'].text
        @customer.address2 = corrected_address_xml.elements['Street2'].text
      rescue Exception => e
      end
    end
    
    def error?
      !@response.root.elements['soap:Body'].elements['soap:Fault'].blank?
    end
    
    def success?
      !error?
    end
    
    def errors
      @response.root.elements['soap:Body'].elements['soap:Fault'].elements['faultstring'].text if error?
    end
    
  private 
  
    def send_request(action = 'Calculate_DS')
      @request = send("build_#{action.underscore}")
      url = URI.parse("http://webservices.esalestax.net/CertiTAX.NET/CertiCalc.asmx")
			timeout(50) do
	      request = Net::HTTP::Post.new(url.path, initheader = {'Content-Type' =>'text/xml; charset=utf-8', 'SOAPAction' => "http://webservices.esalestax.net/CertiTAX.NET/#{action}"})
	  		http = Net::HTTP.new(url.host, url.port)
	  		#http.use_ssl = true
	  		http.start do |http|
	  			request.body = @request
	  			response = http.request(request)
	  			@response = REXML::Document.new response.body
	  		end
			end
    end
    
    def build_calculate
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:Calculate") do
        xml.SerialNumber(SERIAL_NUMBER, "xsi:type" => "xsd:string") 
        xml.ReferredId(@referred_id, "xsi:type" => "xsd:string") 
        xml.Location("", "xsi:type" => "xsd:string")
        xml.MerchantTransactionId(@merchant_transaction_id, "xsi:type" => "xsd:string")
        xml.Nexus(NEXUS, "xsi:type" => "xsd:string")
        xml.ShippingCharge(@shipping_charge, "xsi:type" => "xsd:decimal")
        xml.HandlingCharge(@handling_charge, "xsi:type" => "xsd:decimal")
        xml.Total(@total, "xsi:type" => "xsd:decimal")
        xml.CalculateTax(true, "xsi:type" => "xsd:boolean")
        xml.ConfirmAddress(@confirm_address, "xsi:type" => "xsd:boolean")
        xml.DefaultProductCode(0, "xsi:type" => "xsd:int")
        xml.TaxExemptCertificate(@exempt ? @tax_exempt_certificate : '', "xsi:type" => "xsd:string")
        xml.TaxExemptIssuer(@exempt ? "Unknown" : '', "xsi:type" => "xsd:string")
        xml.TaxExemptReason(@exempt ? "exempt" : '', "xsi:type" => "xsd:string")
        xml.Name("", "xsi:type" => "xsd:string")
        xml.Street1(@customer.address1, "xsi:type" => "xsd:string")
        xml.Street2(@customer.address2, "xsi:type" => "xsd:string")
        xml.City(@customer.city, "xsi:type" => "xsd:string")
        xml.County("", "xsi:type" => "xsd:string")
        xml.State(@customer.state, "xsi:type" => "xsd:string")
        xml.PostalCode(@customer.zip_code, "xsi:type" => "xsd:string")
        xml.Nation(Country.where(:name => @customer.country).first.try(:iso), "xsi:type" => "xsd:string")
      end
      build_request(xml.target!)
    end

    def build_calculate_ds
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:Calculate") do
        xml.tag!("Order", :href => "#id1")
      end
      xml << build_order
      xml << build_address
      xml << build_order_line_items 
      build_request(xml.target!)
    end    
    
    def build_process_attributed_return_ds
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:ProcessAttributedReturn") do
        xml.tag!("OrderChanges", :href => "#id1")
      end
      xml << build_order
      xml << build_address
      xml << build_order_line_items
      build_request(xml.target!)
    end
    
    def build_process_attributed_return
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:ProcessAttributedReturn") do
        xml.CertiTAXTransactionId(@transaction_id, 'xsi:type' => "xsd:string")
        xml.SerialNumber(SERIAL_NUMBER, "xsi:type" => "xsd:string") 
        xml.ReferredId(@referred_id, "xsi:type" => "xsd:string")
        xml.ShippingCharge(@shipping_charge, "xsi:type" => "xsd:decimal")
        xml.HandlingCharge(@handling_charge, "xsi:type" => "xsd:decimal")
        xml.Total(@total, "xsi:type" => "xsd:decimal")
      end
      build_request(xml.target!)
    end
    
    def build_commit
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:Commit") do
        xml.CertiTAXTransactionId(@transaction_id, 'xsi:type' => "xsd:string")
        xml.SerialNumber(SERIAL_NUMBER, 'xsi:type' => "xsd:string")
        xml.ReferredId(@referred_id, 'xsi:type' => "xsd:string")
      end
      build_request(xml.target!)
    end
    
    def build_order(id = 1)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:Order", :id=> "id#{id}", "xsi:type" => "tns:Order") do
        xml.tag!("Address", :href => "#id#{id+1}")
        xml.tag!("LineItems", :href => "#id#{id+2}")
        xml.SerialNumber(SERIAL_NUMBER, "xsi:type" => "xsd:string") 
        xml.ReferredId(@referred_id, "xsi:type" => "xsd:string") 
        xml.Location("", "xsi:type" => "xsd:string")
        xml.CertiTAXTransactionId(@transaction_id, "xsi:type" => "xsd:string") unless @transaction_id.blank?
        xml.MerchantTransactionId(@merchant_transaction_id, "xsi:type" => "xsd:string")
        xml.Nexus(NEXUS, "xsi:type" => "xsd:string")
        xml.ShippingCharge(@shipping_charge, "xsi:type" => "xsd:decimal")
        xml.HandlingCharge(@handling_charge, "xsi:type" => "xsd:decimal")
        xml.Total(@total, "xsi:type" => "xsd:decimal")
        xml.CalculateTax(true, "xsi:type" => "xsd:boolean")
        xml.ConfirmAddress(@confirm_address, "xsi:type" => "xsd:boolean")
        xml.DefaultProductCode(0, "xsi:type" => "xsd:int")
        xml.TaxExemptCertificate(@exempt ? @tax_exempt_certificate : '', "xsi:type" => "xsd:string")
        xml.TaxExemptIssuer(@exempt ? "Unknown" : '', "xsi:type" => "xsd:string")
        xml.TaxExemptReason(@exempt ? "exempt" : '', "xsi:type" => "xsd:string")
      end
      xml.target!
    end
    
    def build_address(id = 2)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("tns:Address", :id => "id#{id}", "xsi:type" => "tns:Address") do
        xml.Name("", "xsi:type" => "xsd:string")
        xml.Street1(@customer.address, "xsi:type" => "xsd:string")
        xml.Street2(@customer.address2, "xsi:type" => "xsd:string")
        xml.City(@customer.city, "xsi:type" => "xsd:string")
        xml.County("", "xsi:type" => "xsd:string")
        xml.State(@customer.state, "xsi:type" => "xsd:string")
        xml.PostalCode(@customer.zip_code, "xsi:type" => "xsd:string")
        xml.Nation(Country.get_country_code(@customer.country), "xsi:type" => "xsd:string")
      end
      xml.target!
    end
    
    def build_order_line_items(id = 3)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.tag!("soapenc:Array", :id => "id#{id}", "soapenc:arrayType" => "tns:OrderLineItem[#{@items.length}]") do
        @items.each do |item|
          id += 1 
          xml.tag!("Item", :href => "#id#{id}") 
        end
      end
      @items.each do |item|
        xml.tag!("tns:OrderLineItem", :id => "id#{id}", "xsi:type" => "tns:OrderLineItem") do
          xml.ItemId item.product.id
          xml.Quantity item.quantity
          xml.ExtendedPrice(item.quantity * (item.respond_to?(:sale_price) ? item.sale_price : item.product.coupon_price(cart)).to_f).to_f.round_to(2) #price * qty
          xml.StockingUnit item.product.item
        end
        id -= 1 
      end
      xml.target!
    end
    
    def build_request(body)
      xml = Builder::XmlMarkup.new :indent => 2
      xml.instruct!
      xml.tag!("soap:Envelope", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd' => "http://www.w3.org/2001/XMLSchema", 'xmlns:soapenc' => "http://schemas.xmlsoap.org/soap/encoding/", "xmlns:tns" => "http://webservices.esalestax.net/CertiTAX.NET", "xmlns:types" => "http://webservices.esalestax.net/CertiTAX.NET/encodedTypes",  "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/") do
        xml.tag!("soap:Body", "soap:encodingStyle" => "http://schemas.xmlsoap.org/soap/encoding/") do
          xml << body
        end
      end
      xml.target!
    end
    
  end

  class CchError < StandardError #:nodoc:
  end
end

