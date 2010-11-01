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
				  :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product => product, :weight => product.weight, 
				  :tax_exempt => product.tax_exempt, :handling_price => product.handling_price, :volume => product.calculated_volume, :pre_order => product.pre_order?, :out_of_stock => product.out_of_stock?)
			end
			get_cart.reset_tax_and_shipping true
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
      @order = cart_to_order_or_quote(:order, options)
		end
		
		def cart_to_quote(options = {})
      @quote = cart_to_order_or_quote(:quote, options)
		end
		
		def cart_to_order_or_quote(klass, options = {})
		  order = klass.to_s.classify.constantize.new(:id => options[:order_id], :subtotal_amount => get_cart.sub_total, :shipping_amount => calculate_shipping(options[:address]), :handling_amount => calculate_handling, :tax_amount => calculate_tax(options[:address]),
			              :tax_transaction => get_cart.reload.tax_transaction, :tax_calculated_at => get_cart.tax_calculated_at, :locale => current_locale, :shipping_service => get_cart.shipping_service)
			order.coupon = get_cart.coupon
			@cart.cart_items.each do |item|
				order.order_items << OrderItem.new(:name => item.name, :item_num => item.item_num, :sale_price => item.price, :quoted_price => item.msrp, :quantity => item.quantity,
				    :locale => item.currency, :product => item.product, :tax_exempt => item.tax_exempt, :discount => item.msrp - item.price, :custom_price => item.custom_price, :coupon_price => item.coupon_price)
			end
			order
		end
		
		# defines logic if payment of an order can be run, or payment has to be tokenized first and payment has to be run manually
		def payment_can_be_run?
		  is_sizzix? || (is_er? && @order && @order.address && @order.address.us?)
		end
		
		def process_order(order)
		  order.address = get_user.shipping_address.clone
  		order.user = get_user
  		order.ip_address = request.remote_ip
  		if order.is_a?(Order)
  		  payment_can_be_run? ? order.open! : order.new!
  		end
  		order.comments = params[:comments] if params
  		if admin_signed_in?
  		  order.customer_rep = current_admin.name
  		  order.customer_rep_id = current_admin.id
  		end
  		if order.respond_to?(:payment) && order.payment && order.payment.save_credit_card
  		  get_user.token = Token.new :last_updated => Time.zone.now, :status => "CURRENT"
  		  get_user.token.copy_common_attributes order.payment, :status
  		  get_user.save
  		end
  		order.save!
  		order.decrement_items! if order.is_a?(Order)
  		flash[:notice] = "Thank you for your #{order.is_a?(Order) ? 'order' : quote_name}.  Below is your order receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		end
		
		# TODO: UK shipping
		def calculate_shipping(address, options={})
			return get_cart.shipping_amount if get_cart.shipping_amount
			if get_cart.coupon && get_cart.coupon.shipping? && get_cart.coupon_conditions_met? && get_cart.coupon.shipping_countries.include?(address.country) && ((address.us? && get_cart.coupon.shipping_states.include?(address.state)) || !address.us?)
			  if get_cart.coupon.free_shipping
			    get_cart.update_attributes :shipping_amount => 0.0, :shipping_service => "STANDARD", :shipping_rates => [{:name => "STANDARD", :type => "STANDARD", :currency => current_currency, :rate => 0.0}]
			    return 0.0
			  elsif get_cart.coupon.fixed?
			    get_cart.update_attributes :shipping_amount => get_cart.coupon.discount_value, :shipping_service => "STANDARD", :shipping_rates => [{:name => "STANDARD", :type => "STANDARD", :currency => current_currency, :rate => get_cart.coupon.discount_value}]
			    return get_cart.coupon.discount_value
			  end
			end
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
      amount, billing, order, tokenize_only = options[:amount], options[:payment], options[:order], options[:tokenize_only]
      get_gateway(options[:system])
      unless billing.use_saved_credit_card
				card_name = correct_card_name(billing.card_name)
        credit_card = ActiveMerchant::Billing::CreditCard.new(:first_name => billing.first_name, :last_name => billing.last_name, :number => billing.full_card_number, :month => billing.card_expiration_month, :year => billing.card_expiration_year,
                          :type => card_name, :verification_value => billing.card_security_code, :start_month => billing.card_issue_month, :start_year => billing.card_issue_year, :issue_number => billing.card_issue_number)
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
					gw_options[:subscription_title] = "#{get_domain.capitalize} Three Easy Payments"
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
      amount_to_charge = tokenize_only ? 0 : amount.to_i #? amount : (total_cart * 100 ).to_i
			timeout(50) do
	      if options[:capture] && !billing.deferred && !billing.use_saved_credit_card && !billing.save_credit_card && !tokenize_only
					@net_response = @gateway.purchase(amount_to_charge, credit_card, gw_options)  
				elsif billing.save_credit_card || tokenize_only && !billing.use_saved_credit_card
				  gw_options.merge!(:number_of_payments => 0, :frequency=> "on-demand", :shipping_address => {}, :start_date => Time.zone.now.strftime("%Y%m%d"),  :subscription_title => "#{credit_card.first_name} #{credit_card.last_name}", :setup_fee => amount_to_charge)
				  @net_response = @gateway.recurring_billing(0, credit_card, gw_options)
				  Rails.logger.info @net_response
				elsif billing.use_saved_credit_card && !tokenize_only
				  Rails.logger.info "use_saved_credit_card: #{amount_to_charge}, #{gw_options}"
				  @net_response = @gateway.pay_on_demand amount_to_charge, gw_options
				elsif billing.use_saved_credit_card && tokenize_only
				  @payment = billing
				  @payment.copy_common_attributes get_user.token
				  @payment.paid_amount = amount_to_charge
				  return @payment
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
        @payment.mask_card_number
        if @payment.use_saved_credit_card && !options[:use_payment_token] && get_user.token
          @payment.card_number = get_user.token.card_number
        	@payment.card_expiration_month = get_user.token.card_expiration_month
        	@payment.card_expiration_year = get_user.token.card_expiration_year
        	@payment.card_name = get_user.token.card_name
        end
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
    
    # pass a Payment object as the first argument
    def void_cc_transaction(payment, options = {})
      get_gateway
			timeout(30) do
      	@net_response = @gateway.void(payment.authorization, options)
			end
      if @net_response.success?
        payment.void_at = Time.zone.now
        payment.void_amount = @net_response.params['amount']
        payment.void_authorization = @net_response.authorization
        payment.status = "VOID"
        payment.save(false)
      end
      @net_response
    end
    
    def refund_cc_transaction(payment, options = {})
      get_gateway
      options.merge!(:order_id => "REFUND#{payment.order.id}", :description => "REFUND#{payment.order.id}", :currency => payment.order.locale == 'en-UK' ? "GBP" : "EUR") if is_uk?
      timeout(30) do
				@net_response = @gateway.credit(payment.paid_amount * 100, payment.authorization, options)
			end
      if @net_response.success?
        payment.refunded_at = Time.zone.now
        payment.refunded_amount = @net_response.params['amount'] if @net_response.params['amount']
        payment.refund_authorization = @net_response.authorization
        payment.status = "REFUND"
        payment.save(false)
      end
      @net_response
    end
    
    # example: tokenize_billing_info(credit_card, :billing_address=>{:address1 => @billing.address, :address2 => @billing.address2, :country => @billing.country, :company => @billing.company, :zip => @billing.zip_code, :phone => @billing.phone, :state => @billing.state, :city => @billing.city}, :email => @billing.email, :order_id => get_user.id, :customer_account_id => get_user.erp_id)
    def tokenize_billing_info(credit_card, options)     
			subscription_title = credit_card.first_name ? "#{credit_card.first_name} #{credit_card.last_name}" : "create customer"
      options.merge!(:number_of_payments => 0, :frequency=> "on-demand", :shipping_address => {}, :start_date => Time.zone.now.strftime("%Y%m%d"),  :subscription_title => subscription_title, :setup_fee => 0)
      get_gateway options[:system]
      timeout(30) do
        @net_response = @gateway.recurring_billing(0, credit_card, options)
      end
      @net_response
    end
    
    # retreive tokenized customer billing info
    # example: 
    #   get_tokenized_billing_info :subscription_id=>"2774176050310008284282", :order_id=>"aweweweqq"
    def get_tokenized_billing_info(options)
      get_gateway options[:system]
      timeout(30) do
        @net_response = @gateway.retreive_customer_info options
      end
      @net_response
    end
    
    # updates current user's payment/subscription token from cybersource
    def update_user_token
      if get_user.token && !get_user.token.current?
  		  get_tokenized_billing_info :subscription_id => get_user.token.subscriptionid, :order_id =>  get_user.id
  		  if @net_response.success? && @net_response.params['status'] == 'CURRENT'
  		    get_user.token.update_attributes :status => "CURRENT",  :card_number => @net_response.params['cardAccountNumber'], :card_name => get_gateway.cc_code_to_cc(@net_response.params['cardType']), :card_expiration_month => @net_response.params['cardExpirationMonth'],
  		      :card_expiration_year => @net_response.params['cardExpirationYear'], :first_name => @net_response.params['firstName'], :last_name => @net_response.params['lastName'], :city => @net_response.params['city'], :country => @net_response.params['country'], :address1 => @net_response.params['street1'],
  		      :zip_code => @net_response.params['postalCode'], :state => @net_response.params['state'], :email => @net_response.params['email'], :last_updated => Time.zone.now
  		  else
  		    get_user.token.delete
  		  end
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
      ActiveMerchant::Billing::Base.mode = :test unless Rails.env == 'production' 
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
		
		def new_payment
  		@payment = Payment.new
  		@payment.copy_common_attributes(get_user.billing_address) if get_user.billing_address
  		@payment.use_saved_credit_card = true if get_user.token && get_user.token.current?
  		@payment.attributes = params[:payment] if params[:payment]
  		@payment.subscriptionid = get_user.token.subscriptionid if get_user.token && get_user.token.current?
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