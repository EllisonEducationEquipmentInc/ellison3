module ShoppingCart
	module ClassMethods
		
	end
	
	module InstanceMethods
		
		class RealTimeCartError < StandardError; end #:nodoc
		
	private 
		
		def get_cart
      @cart ||= (Cart.find(session[:shopping_cart]) rescue Cart.new)
    end
		
		def add_2_cart(product, qty = 1)
			if item = get_cart.cart_items.find_item(product.item_num)
				item.quantity += qty
			else
				get_cart.cart_items << CartItem.new(:name => product.name, :item_num => product.item_num, :sale_price => product.sale_price, :msrp => product.msrp, :price => product.price, 
				  :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product_id => product.id, :weight => product.weight, 
				  :tax_exempt => product.tax_exempt, :handling_price => product.handling_price, :volume => product.calculated_volume)
			end
			get_cart.reset_tax_and_shipping
			get_cart.apply_coupon_discount
			session[:shopping_cart] ||= get_cart.id.to_s
		end
		
		def remove_cart(item_num)
			cart_item = get_cart.cart_items.find_item(item_num)
			cart_item.delete
			get_cart.reset_tax_and_shipping
			get_cart.apply_coupon_discount
			cart_item.id.to_s
		end
		
		def clear_cart
			get_cart.clear
			session[:shopping_cart], @cart = nil
		end
		
		def cart_to_order(options = {})
			@order = Order.new(:id => options[:order_id], :subtotal_amount => get_cart.sub_total, :shipping_amount => calculate_shipping(options[:address]), :handling_amount => calculate_handling, :tax_amount => calculate_tax(options[:address]), :tax_transaction => get_cart.reload.tax_transaction, :tax_calculated_at => get_cart.tax_calculated_at, :locale => current_locale, :shipping_service => get_cart.shipping_service)
			@cart.cart_items.each do |item|
				@order.order_items << OrderItem.new(:name => item.name, :item_num => item.item_num, :sale_price => item.price, :quoted_price => item.msrp, :quantity => item.quantity, :locale => item.currency, :product_id => item.product_id, :tax_exempt => item.tax_exempt, :discount => item.msrp - item.price)
			end
			@order
		end
		
		# TODO: UK shipping
		def calculate_shipping(address, options={})
			return get_cart.shipping_amount if get_cart.shipping_amount
			options[:weight] ||= get_cart.total_weight
			options[:shipping_service] ||= "FEDEX_GROUND"
			options[:package_length] ||= (get_cart.total_volume**(1.0/3.0)).round
			options[:package_width] ||= (get_cart.total_volume**(1.0/3.0)).round
			options[:package_height] ||= (get_cart.total_volume**(1.0/3.0)).round
			rate = if is_us?
				fedex_rate(address, options)
				@shipping_service = @rates.detect {|r| r.type == options[:shipping_service]} ? options[:shipping_service] : @rates.sort {|x,y| x.rate <=> y.rate}.first.type
				@rates.detect {|r| r.type == options[:shipping_service]}.try(:rate) || @rates.sort {|x,y| x.rate <=> y.rate}.first.rate
			else
				@shipping_service = "STANDARD"
				0.0
			end
			get_cart.update_attributes :shipping_amount => rate, :shipping_service => @shipping_service, :shipping_rates => @rates ? fedex_rates_to_a(@rates) : [{:name => @shipping_service, :type => @shipping_service, :currency => current_currency, :rate => rate}]
			rate
		rescue Exception => e
			e.message
		end
		
		# convert an array of Shippinglogic::FedEx::Rate::Service elements to an array of hashes that can be saved in the db
		def fedex_rates_to_a(rates)
			a = []
			rates.each do |rate|
				h = {:rate => rate.rate.to_f}
				[:name, :type, :saturday, :delivered_by, :speed, :currency].each {|m| h[m]=rate.send(m) }
				a << h
			end
			a
		end
		
		def get_delayed_shipping
			tries = 0
			get_cart
			while @cart.shipping_amount.blank? && tries < 5
				Rails.logger.info "CCH: waiting for shipping amount..."
				tries += 1
				sleep(2**tries) 
				@cart = get_cart.reload
			end
			get_cart.shipping_amount
		end
		
		def calculate_handling
			get_cart.handling_amount
		end
		
		# TODO: UK tax
		def calculate_tax(address, options={})
			return get_cart.tax_amount if get_cart.tax_amount && get_cart.tax_calculated_at && get_cart.tax_calculated_at > 1.hour.ago
			total_tax = if %w(CA IN WA UT).include?(address.state)
				cch_sales_tax(address)
        @cch.total_tax.to_f				
			else
				0.0
			end
			get_cart.update_attributes :tax_amount => total_tax, :tax_transaction => @cch ? @cch.transaction_id : nil, :tax_calculated_at => Time.now
			total_tax
		end
		
		def calculate_shipping_and_handling
			calculate_shipping + calculate_handling
		end
		
		# TODO: package dimensions!
		#
		# Calculates fedex shipping rates based on shipping address and weight.
		# first argument should be an Address object.
		# available options:
		# 	:request_type  	#=> 'ACCOUNT' (default) or 'LIST'
		# 	:residential 		#=> true or false (default)  
		# 	:weight 				#=> weight in lbs (required)
		# 	:service				#=> fedex service type: "FEDEX_GROUND" (default), "GROUND_HOME_DELIVERY", "FEDEX_EXPRESS_SAVER", "FEDEX_2_DAY", "STANDARD_OVERNIGHT", "PRIORITY_OVERNIGHT", "FIRST_OVERNIGHT", "FEDEX_2_DAY_SATURDAY_DELIVERY", "PRIORITY_OVERNIGHT_SATURDAY_DELIVERY", "FEDEX_3_DAY_FREIGHT", "FEDEX_2_DAY_FREIGHT", "FEDEX_1_DAY_FREIGHT", "FEDEX_3_DAY_FREIGHT_SATURDAY_DELIVERY", "FEDEX_2_DAY_FREIGHT_SATURDAY_DELIVERY", "FEDEX_1_DAY_FREIGHT_SATURDAY_DELIVERY", "INTERNATIONAL_GROUND", "INTERNATIONAL_ECONOMY", "INTERNATIONAL_PRIORITY", "INTERNATIONAL_FIRST", "INTERNATIONAL_PRIORITY_SATURDAY_DELIVERY", "INTERNATIONAL_ECONOMY_FREIGHT", "INTERNATIONAL_PRIORITY_FREIGHT"
		# 	:packaging_type #=> "FEDEX_ENVELOPE", "FEDEX_PAK", "FEDEX_BOX" (default), "FEDEX_TUBE", "FEDEX_10KG_BOX", "FEDEX_25KG_BOX", "YOUR_PACKAGING" - needs package dimensions (:package_length => 12, :package_width => 12, :package_height => 12)
		def fedex_rate(address, options={})														
			@fedex = Shippinglogic::FedEx.new(FEDEX_AUTH_KEY, FEDEX_SECURITY_CODE, FEDEX_ACCOUNT_NUMBER, FEDEX_METER_NUMBER, :test => false)
			@rates = @fedex.rate(:shipper_company_name => "Ellison", :shipper_streets => '25862 Commercentre Drive', :shipper_city => 'Lake Forest', :shipper_state => 'CA', :shipper_postal_code => "92630", :shipper_country => "US", 
													:recipient_name => "#{address.first_name} #{address.last_name}", :recipient_company_name => address.company, :recipient_streets => "#{address.address1} #{address.address2}", :recipient_city => address.city,  :recipient_postal_code => address.zip_code, :recipient_state => address.state, :recipient_country => country_2_code(address.country), :recipient_residential => options[:residential], 
													:package_weight => options[:weight], :rate_request_types => options[:request_type] || "ACCOUNT", :packaging_type => options[:packaging_type] || "YOUR_PACKAGING", :package_length => options[:package_length] || 12, :package_width => options[:package_width] || 12, :package_height => options[:package_height] || 12, :ship_time => options[:ship_time] || skip_weekends(Time.now, 3.days))													
	    @rates
	  end
		
		def cch_sales_tax(customer, options = {})
			Rails.logger.info "Getting CCH tax for #{customer.inspect}"
			options[:shipping_charge] ||= get_delayed_shipping
			options[:handling_charge] ||= calculate_handling
			options[:cart] ||= get_cart.reload
			options[:tax_exempt_certificate] ||= get_user.tax_exempt_certificate
			options[:exempt] ||= get_user.tax_exempt
			options[:confirm_address] ||= false
			tries = 0
      begin
				tries += 1
      	@cch = CCH::Cch.new(:action => 'calculate', :cart => options[:cart], :confirm_address => options[:confirm_address],  :customer => customer, :handling_charge => options[:handling_charge], :shipping_charge => options[:shipping_charge], :exempt => options[:exempt], :tax_exempt_certificate => options[:tax_exempt_certificate])
      rescue Timeout::Error => e
				if tries < 3         
			    sleep(2**tries)            
			    retry                      
			  end
      	Rails.logger.error "!!! CCH Timed out. Retrying..."
      end
    end

		def process_card(options = {})
      amount, billing, order = options[:amount], options[:payment], options[:order]
      get_gateway(options[:system])
      unless billing.use_saved_credit_card
				card_name = correct_card_name(billing.card_name)
        credit_card = ActiveMerchant::Billing::CreditCard.new(:first_name => billing.first_name, :last_name => billing.last_name, :number => billing.full_card_number, :month => billing.card_expiration_month, :year => billing.card_expiration_year, :type => card_name, :verification_value => billing.card_security_code, :start_month => billing.card_issue_month, :start_year => billing.card_issue_year, :issue_number => billing.card_issue_number)
        raise "Credit card is invalid. #{credit_card.errors}" if !credit_card.valid?
      end
      if is_us?
        gw_options = {:email => billing.email, :order_id => order}
        gw_options[:billing_address] = {:company => billing.company, :phone => billing.phone,  :address1 => billing.address1, :city => billing.city, :state => billing.state, :country => billing.country, :zip => billing.zip_code} unless billing.use_saved_credit_card
      	gw_options[:subscription_id] = billing.subscriptionid
      	if billing.deferred
					gw_options[:setup_fee] = (calculate_setup_fee(subtotal_cart, calculate_shipping_and_handling(get_cart, get_ship_to,  get_cart.shipping_method), calculate_tax(get_cart, get_ship_to, true)) * 100).round
					gw_options[:number_of_payments] = billing.number_of_payments
					gw_options[:frequency] = billing.frequency
					gw_options[:start_date] = 1.months.since.strftime("%Y%m%d")
					gw_options[:subscription_title] = "Sizzix.com Three Easy Payments"
					gw_options[:customer_account_id] = get_user.id
					amount = amount ? amount : (subtotal_cart/(billing.number_of_payments + 1.0) * 100 ).round
				end
			else
        gw_options = {
          :order_id => order,
          :address => {},
          :billing_address => {:name => billing.first_name + ' ' + billing.last_name, :address1 => billing.address1, :city => billing.city, :state => billing.state, :country => billing.country, :zip => billing.zip_code, :phone => billing.phone}
        }
        gw_options[:currency] = is_gbp? ? "GBP" : "EUR" 
      end
      amount_to_charge = amount.to_i #? amount : (total_cart * 100 ).to_i
			timeout(50) do
	      if options[:capture] && !billing.deferred && !billing.use_saved_credit_card
					@net_response = @gateway.purchase(amount_to_charge, credit_card, gw_options)  
				elsif billing.use_saved_credit_card
				  @net_response = @gateway.pay_on_demand amount_to_charge, gw_options
				elsif billing.deferred
					@net_response = @gateway.recurring_billing(amount_to_charge, credit_card, gw_options)  
				else
	      	@net_response = @gateway.authorize(amount_to_charge, credit_card, gw_options)
				end
			end
      if @net_response.success?
        #if @net_response.params["AddressResult"] != "MATCHED" || @net_response.params["PostCodeResult"] != "MATCHED" 
        #  raise "Payment address and/or postcode don't match the address on your credit card statement." 
        #elsif @net_response.params["CV2Result"] != "MATCHED"
        #  raise "CVV code is invalid. Please try again."
        #else
        @payment = billing
        @payment.paid_amount = amount ? amount/100 : total_cart
        @payment.vendor_tx_code = order
        process_gw_response @net_response
      else 
				if is_us? && (@net_response.params["reasonCode"] == "200" || @net_response.params["reasonCode"] == "230")
					timeout(50) do
						@reversal = @gateway.authorization_reversal(amount_to_charge, @net_response.params["requestID"], @net_response.params["requestToken"], :order_id => @net_response.params["merchantReferenceCode"])
						logger.info "[!] authorization_reversal: #{@reversal.message} #{@reversal.params.inspect}"
	        end
				end
				message = []
        message << @net_response.message
        message << "AVS (Address Verification Service) result: " + @net_response.avs_result["message"] if @net_response.avs_result["message"] && !%w(D M X Y V 1 2 3 4).include?(@net_response.avs_result["code"])
        message << "CVV (Security Code): " + @net_response.cvv_result["message"] if @net_response.cvv_result["message"] && !%w(M 1 2 3).include?(@net_response.cvv_result["code"])
        raise 'Your card could not be authorized! Please correct any details below and try again, try another card or <a href="/contact">contact us</a> for further assistance.<br><br> ' + message.join("<br>")
      end
    end

		def correct_card_name(card_name)
      if card_name == 'electron' || card_name == 'delta'
        'visa'
      elsif card_name == 'MasterCard'
        'master'
      else
        card_name.underscore
      end
		end
		
		def country_2_code(country)
	  	Country.where(:name => country).first.try :iso
	  end
		
		def process_gw_response(response)
      if is_us?
				# cybersource mappings
        @payment.cv2_result ||= response.params['cvCode']
        @payment.status ||= response.params['decision']
        @payment.vpstx_id = response.params["reconciliationID"]
        @payment.security_key ||= response.params["merchantReferenceCode"]
        @payment.tx_auth_no ||= response.params['authorizationCode']
        @payment.status_detail ||= response.params["processorResponse"]
        @payment.address_result ||= response.avs_result['street_match'] #response.params['avsCode']
        @payment.post_code_result ||= response.avs_result['postal_match']
				@payment.subscriptionid ||= response.params['subscriptionID']
        @payment.paid_amount = response.params["amount"]
        @payment.authorization = response.authorization
      else
				# protx (sage) mappings
        @payment.status ||= response.params["Status"]
        @payment.vpstx_id ||= response.params["VPSTxId"]
        @payment.security_key ||= response.params["SecurityKey"]
        @payment.tx_auth_no ||= response.params["TxAuthNo"]
        @payment.status_detail ||= response.params["StatusDetail"]
        @payment.address_result ||= response.params["AddressResult"]
        @payment.post_code_result ||= response.params["PostCodeResult"]
        @payment.cv2_result ||= response.params["CV2Result"]
        @payment.authorization ||= response.authorization
      end
      @payment.paid_at = Time.zone.now
    end
		
		def get_gateway(system = nil)
      unless system
        system = if is_sizzix_us?
                   'sizzix_us'
                 elsif is_ee_us? 
                   'ee_us'
                 elsif is_er? 
                   'er'
                 else
                   'uk'
                 end
      end
      options = if system == 'sizzix_us'
                {:merchant_account => {
                   :name => 'cyber_source',
                   :user_name => 'sizzix',
                   :password => 'gjSlJTQJGbiPL5fAwVZ2ho0r98LmsYw1FOdGq675dIZzsASmsv5/M2kKhc3mwAtPGlVBAf12UVToDRYqcXpQJUtkXCvp1oDQ0RyqmQlTH9CGUGh3lR+7jVwJ5+8qokWtWnrYuUU3JDE4suev4jYGCQ9lutmXAmhH5+OpxGG84TRsV7APDoSoJM4UhtGpYnaGjSv3wuaxjDUU50arrvl0hnOwBKay/n8zaQqFzebAC08aVUEB/XZRVOgNFipxelAlS2RcK+nWgNDRHKqZCVMf0IZQaHeVH7uNXAnn7yqiRa1aeti5RTckMTiy56/iNgYJD2W62ZcCaEfn46nEYbzhNA==',
                   :login => 'sizzix'}}
              elsif system == 'ee_us'
                 {:merchant_account => {
                   :name => 'cyber_source',
                   :user_name => 'ellison',
                   :password => 'wpc4lHdGRv/Q8rXAmLy9bNdrZr2tTZdU5SypZVRb4Q2hapwjIIiYszLzcrQZG6R1fh+76JKLhlqIjeoY/Hzvfh2OD+/GQzUznEhn7HOk4rPWiLHQogY7ZpCCQNhEt2SCaeMjHrpg2ugpPvriX2MT7hPt8L2XeRddpYdIFUSL2Y/iLhCFg3CDVmQ4gUcYZ1Ns12tmva1Nl1TlLKllVFvhDaFqnCMgiJizMvNytBkbpHV+H7vokouGWoiN6hj8fO9+HY4P78ZDNTOcSGfsc6Tis9aIsdCiBjtmkIJA2ES3ZIJp4yMeumDa6Ck++uJfYxPuE+3wvZd5F12lh0gVRIvZjw==',
                   :login => 'ellison'}}
             elsif system == 'er'
                {:merchant_account => {
                  :name => 'cyber_source',
                  :user_name => 'ellisonretail',
                  :password => 'skoRfHH6Z9g5muYxQYau+F3xx6VpMvBgIiaYF7ehVa6Fi+oMmU2mG+naCHaPQvJ7maLAV+Fv8DHwUjvB755DujWNmRm0JK257S//v8Amf+coDwzBukjQIw3rwKmTribTW9swVYFeTNSzIe7PkHzkJdqVzSr6MyL1b1E5CditD6FSbqpYS9EwS+SDAfReWVUub1jHpWky8GAiJpgXt6FVroWL6gyZTaYb6doIdo9C8nuZosBX4W/wMfBSO8HvnkO6NY2ZGbQkrbntL/+/wCZ/5ygPDMG6SNAjDevAqZOuJtNb2zBVgV5M1LMh7s+QfOQl2pXNKvozIvVvUTkJ2K0PoQ==',
                  :login => 'ellisonretail'}}
              else
                 {:merchant_account => {
                   :name => 'sage',
                   :user_name => 'ellison',
                   :password => 'ellisond',
                   :login => 'ellisonadmin'}}
               end
      config = Config.new(options)
      ActiveMerchant::Billing::Base.mode = :test unless RAILS_ENV == 'production' 
      @gateway = ActiveMerchant::Billing::Base.gateway(config.name.to_s).new(:login => config.user_name.to_s, :password => config.password.to_s)    
    rescue
      raise 'Invalid ActiveMerchant Gateway'
    end
		
		def skip_weekends(date, inc)
		  date += inc
		  while (date.wday % 7 == 0) or (date.wday % 7 == 6) do
		    date += inc
		  end   
		  date
		end

		class Config
	    attr_reader :name, :user_name, :password
	    def initialize(config)
	      raise "Please configure the ActiveMerchant Gateway" if config[:merchant_account] == nil
	      @name = config[:merchant_account][:name].to_s
	      @user_name = config[:merchant_account][:user_name].to_s
	      @password  = config[:merchant_account][:password].to_s
	    end
	  end
	end
	
	def self.included(receiver)
		receiver.extend         ClassMethods
		receiver.send :include, InstanceMethods
	end
end