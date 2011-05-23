module ShoppingCart
	module ClassMethods
		
	end
	
	module InstanceMethods
		
		class RealTimeCartError < StandardError; end #:nodoc
		
	private 
		
		def get_cart
      @cart ||= (Cart.find(session[:shopping_cart]) rescue Cart.new)
      session[:shopping_cart] = @cart.id.to_s
      @cart
    end
		
		def add_2_cart(product, qty = 1)
			if item = get_cart.cart_items.find_item(product.item_num)
				item.quantity += qty
			else
				get_cart.cart_items << CartItem.new(:name => product.name, :item_num => product.item_num, :sale_price => product.sale_price, :msrp => product.msrp_or_wholesale_price, :price => product.price, 
				  :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product => product, :weight => product.virtual_weight, :actual_weight => product.weight, :retailer_price => product.retailer_price,
				  :tax_exempt => product.tax_exempt, :handling_price => product.handling_price, :pre_order => product.pre_order?, :out_of_stock => product.out_of_stock?, :minimum_quantity => product.minimum_quantity)
			end
			get_cart.reset_tax_and_shipping true
			get_cart.apply_coupon_discount
			session[:shopping_cart] ||= get_cart.id.to_s
		end
		
		def change_qty(item_num, qty)
		  cart_item = get_cart.cart_items.find_item(item_num)
		  return cart_item if is_er? && cart_item.minimum_quantity > qty
			cart_item.quantity = qty
			get_cart.reset_tax_and_shipping
			get_cart.apply_coupon_discount
			cart_item
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
		  order = klass.to_s.classify.constantize.new(:id => options[:order_id], :subtotal_amount => get_cart.sub_total, :shipping_amount => calculate_shipping(options[:address]), :handling_amount => calculate_handling, :tax_amount => calculate_tax(options[:address]), :coupon_code => get_cart.coupon_code,
			              :tax_transaction => get_cart.reload.tax_transaction, :tax_calculated_at => get_cart.tax_calculated_at, :locale => current_locale, :shipping_service => get_cart.shipping_service, :order_reference => get_cart.order_reference, :vat_percentage => vat, :vat_exempt => vat_exempt?, 
			              :tax_exempt => tax_exempt?, :tax_exempt_number => tax_exempt? ? get_user.tax_exempt_certificate : nil, :total_discount => gross_price(get_cart.total_discount))
			order.coupon = get_cart.coupon
			if get_cart.cod?
			  order.cod_account_type = get_user.cod_account_type
			  order.cod_account = get_user.cod_account
			end
			@cart.cart_items.each do |item|
				order.order_items << OrderItem.new(:name => item.name, :item_num => item.item_num, :sale_price => item.price, :quoted_price => item.msrp, :quantity => item.quantity,
				    :locale => item.currency, :product => item.product, :tax_exempt => item.tax_exempt, :discount => item.msrp - item.price, :custom_price => item.custom_price, 
				    :coupon_price => item.coupon_price, :vat => calculate_vat(item.price), :vat_percentage => vat, :vat_exempt => vat_exempt?, :upsell => item.upsell)
			end
			order.address ||= get_user.shipping_address.clone
			order
		end
		
		def order_to_cart(order)
		  get_cart
		  order.order_items.each do |item|
		    cart_item = CartItem.new(:price => item.sale_price, :small_image => item.product.small_image, :added_at => Time.now, :pre_order => item.product.pre_order?, 
		      :out_of_stock => item.product.out_of_stock?, :weight => item.product.virtual_weight, :actual_weight => item.product.weight, :msrp => item.product.msrp_or_wholesale_price, :minimum_quantity => item.product.minimum_quantity, 
		      :retailer_price => item.product.retailer_price, :currency => item.locale )
		    cart_item.copy_common_attributes item
		    cart_item.custom_price = true if cart_item.price != item.product.price
		    get_cart.cart_items << cart_item
		  end
		  get_cart.coupon = order.coupon
		  get_cart.save
		end
		
		# defines logic if payment of an order can be run, or payment has to be tokenized first and payment has to be run manually
		def payment_can_be_run?
		  !(backorder_allowed? && @order.order_items.any? {|e| e.product.out_of_stock?}) && (is_sizzix? || (is_er? && @order && @order.address)) && !@order.payment.try(:purchase_order)
		end
		
		def process_order(order)
  		order.user = get_user
  		order.ip_address = request.remote_ip
  		if order.is_a?(Order)
  		  payment_can_be_run? ? order.open! : order.new!
  		  order.clickid = cookies[:clickid]
  			order.utm_source = cookies[:utm_source]
  			order.tracking = cookies[:tracking]
  			order.estimated_ship_date = Time.zone.now
  		end
  		order.comments = params[:comments] if params
  		order.name = params[:quote_name] if order.is_a?(Quote) && params && params[:quote_name]
  		if admin_signed_in?
  		  order.customer_rep = current_admin.employee_number
  		  order.customer_rep_id = current_admin.id
  		end
  		if order.respond_to?(:payment) && order.payment && order.payment.save_credit_card
  		  get_user.token = Token.new :last_updated => Time.zone.now, :status => "CURRENT"
  		  get_user.token.copy_common_attributes order.payment, :status
  		  get_user.save
  		end
  		order.save!
  		if order.is_a?(Order) && order.payment
  		  order.decrement_items! 
  		  order.user.add_to_owns_list order.order_items.map {|e| e.product_id}
  		end
  		flash[:notice] = "Thank you for your #{order.is_a?(Order) ? 'order' : quote_name}.  Below is your #{order.is_a?(Order) ? 'order' : quote_name} receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		end
		
		# shipping logic: 
		#   SZUS:  Shipping Rates (cart subtotal based)
		#   ER: domestic - US Shipping Rates (by weight/zone), international - real fedex call.
		#   SZUK, EEUK: Shipping Rates (cart subtotal based)
		#   EEUS: Shipping Rates (cart subtotal based)
		def calculate_shipping(address, options={})
			return get_cart.shipping_amount if get_cart.shipping_amount && get_cart.shipping_calculated_at > 1.hour.ago
			@shipping_discount_percentage = 0.0
			coupon = if get_cart.coupon.present? && get_cart.coupon.shipping? && get_cart.coupon_conditions_met? && get_cart.shipping_conditions_met?(address)
			  get_cart.coupon
			elsif get_cart.coupon.present? && get_cart.coupon.group? && get_cart.coupon_conditions_met? && get_cart.coupon.children.detect {|c| c.shipping? && get_cart.coupon_conditions_met?(c) && get_cart.shipping_conditions_met?(address, c)}.present?
			  get_cart.coupon.children.detect {|c| c.shipping? && get_cart.coupon_conditions_met?(c) && get_cart.shipping_conditions_met?(address, c)}
			else
			  shipping_promotion_coupon_discount(address)
			end
			if coupon.present?
			  if coupon.free_shipping
			    get_cart.update_attributes :shipping_calculated_at => Time.now, :shipping_amount => 0.0, :shipping_service => "STANDARD", :shipping_rates => [{:name => "STANDARD", :type => "STANDARD", :currency => current_currency, :rate => 0.0}]
			    return 0.0
			  elsif coupon.fixed?
			    get_cart.update_attributes :shipping_calculated_at => Time.now, :shipping_amount => coupon.discount_value, :shipping_service => "STANDARD", :shipping_rates => [{:name => "STANDARD", :type => "STANDARD", :currency => current_currency, :rate => coupon.discount_value}]
			    return coupon.discount_value
			  elsif coupon.percent?
			    @shipping_discount_percentage = coupon.discount_value
			  end
			end
			options[:weight] ||= get_cart.total_weight
			options[:shipping_service] ||= "FEDEX_GROUND" if address.us?
			options[:packaging_type] ||= "YOUR_PACKAGING"
      # options[:package_length] ||= (get_cart.total_volume**(1.0/3.0)).round
      # options[:package_width] ||= (get_cart.total_volume**(1.0/3.0)).round
      # options[:package_height] ||= (get_cart.total_volume**(1.0/3.0)).round
			if is_er_us? #is_us? && !is_ee? #address.us?
			  us_shipping_rate(address, options) || fedex_rate(address, options) 
			else
			  shipping_rate(address, options)
			end
			@rates << get_user.cod_account_info if @rates && cod_allowed? && get_user.cod_account_info
			@shipping_service = @rates.detect {|r| r.type == options[:shipping_service]} ? options[:shipping_service] : @rates.sort {|x,y| x.rate <=> y.rate}.first.type
			rate = @rates.detect {|r| r.type == options[:shipping_service]}.try(:rate) || @rates.sort {|x,y| x.rate <=> y.rate}.first.rate
			rate -= (0.01 * @shipping_discount_percentage * rate).round(2)
			get_cart.update_attributes :shipping_calculated_at => Time.now, :shipping_amount => rate, :shipping_service => @shipping_service, :shipping_rates => @rates ? fedex_rates_to_a(@rates, @shipping_discount_percentage) : [{:name => @shipping_service, :type => @shipping_service, :currency => current_currency, :rate => rate}]
			rate
		end
		
		# get eligible shipping coupons that don't require coupon code
		def shipping_promotion_coupon_discount(address)
		  Coupon.available.no_code_required.by_location(address).detect {|e| get_cart.coupon_conditions_met?(e)}
		end
		
		# convert an array of Shippinglogic::FedEx::Rate::Service elements to an array of hashes that can be saved in the db
		def fedex_rates_to_a(rates, shipping_discount_percentage = 0.0)
			a = []
			rates.each do |rate|
			  r = rate.rate.to_f
				h = {:rate => r - (0.01 * shipping_discount_percentage * r).round(2)}
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
		
		# only for systems where shipping is NOT weight based
		def calculate_handling
			is_ee? || is_sizzix_uk? ? get_cart.handling_amount : 0.0
		end
		
		def calculate_tax(address, options={})
			return get_cart.tax_amount if get_cart.tax_amount && get_cart.tax_calculated_at && get_cart.tax_calculated_at > 1.hour.ago
			total_tax = if is_us? && calculate_tax?(address.state)
				cch_sales_tax(address)
        @cch.total_tax.to_f		
      elsif is_uk? 
        calculate_vat(get_cart.sub_total, vat_exempt?)
			else
				0.0
			end
			get_cart.update_attributes :tax_amount => total_tax, :tax_transaction => @cch ? @cch.transaction_id : nil, :tax_calculated_at => Time.zone.now #, :vat_percentage => 
			total_tax
		end
		
		def calculate_shipping_and_handling
			calculate_shipping + calculate_handling
		end
		
		# US shipping rates based on weight + Fedex zones
		def us_shipping_rate(address, options={})
		  return false unless address.us?
		  zone = address.apo? ? "APO" : FedexZone.find_by_zip(address.zip_code).try(:zone)
		  rates = FedexRate.find_by_weight(options[:weight])
		  return false unless rates && zone && !rates.rates[zone.to_s].blank?
		  @rates = []
		  rates.rates[zone.to_s].each do |k,v|
		    service = Shippinglogic::FedEx::Rate::Service.new
		    service.name = k.titleize
		    service.type = k.upcase
		    service.rate = v
		    @rates << service
		  end
		  @rates
		end
		
		# shipping rates based on cart subtotal
		def shipping_rate(address, options={})
		  shipping_subtotal_amount = options[:subtotal_amount] || subtotal_cart
		  rate = ShippingRate.where(:system => current_system, :"price_min_#{current_currency}".lte => shipping_subtotal_amount, :"price_max_#{current_currency}".gte => shipping_subtotal_amount, :zone_or_country => address.us? ? FedexZone.get_zone_by_address(address).try(:to_s) : address.country).first
		  if rate.blank?
		    msg = if is_sizzix_us? && !address.us?
	          "Sizzix.com only ships to U.S addresses. Please change your shipping address, or place your order on sizzix.co.uk"
		      elsif is_sizzix_uk? && address.us?
		        "Sizzix.co.uk does not ship to U.S addresses. Please change your shipping address, or place your order on sizzix.com"
		      else
		        'Please try again later.'
		      end
		    raise "Unable to calculate shipping. #{msg}" 
		  end
		  @rates = []
		  standard = Shippinglogic::FedEx::Rate::Service.new
		  standard.name = standard.type = "STANDARD"
		  standard.rate = rate.percentage ? (shipping_subtotal_amount * rate.send("standard_rate_#{current_currency}")/100.0).round(2) : rate.send("standard_rate_#{current_currency}")
		  @rates << standard
		  unless rate.send("rush_rate_#{current_currency}").blank?
		    rush = Shippinglogic::FedEx::Rate::Service.new
  		  rush.name = rush.type = "RUSH"
  		  rush.rate = rate.percentage ? (shipping_subtotal_amount * rate.send("rush_rate_#{current_currency}")/100.0).round(2) : rate.send("rush_rate_#{current_currency}")
  		  @rates << rush
		  end
		  @rates
		end
		
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
		  Rails.logger.info "Getting Fedex rate for #{address.inspect}"											
			@fedex = Shippinglogic::FedEx.new(FEDEX_AUTH_KEY, FEDEX_SECURITY_CODE, FEDEX_ACCOUNT_NUMBER, FEDEX_METER_NUMBER, :test => false)
			@rates = @fedex.rate(:service_type => options[:service_type], :shipper_company_name => "Ellison", :shipper_streets => '25862 Commercentre Drive', :shipper_city => 'Lake Forest', :shipper_state => 'CA', :shipper_postal_code => "92630", :shipper_country => "US", 
													:recipient_name => "#{address.first_name} #{address.last_name}", :recipient_company_name => address.company, :recipient_streets => "#{address.address1} #{address.address2}", :recipient_city => address.city,  :recipient_postal_code => address.zip_code, :recipient_state => address.with_state? ? address.state : nil, :recipient_country => country_2_code(address.country), :recipient_residential => options[:residential], 
													:package_weight => options[:weight], :rate_request_types => options[:request_type] || "ACCOUNT", :packaging_type => options[:packaging_type] || "FEDEX_BOX", :package_length => options[:package_length] || 12, :package_width => options[:package_width] || 12, :package_height => options[:package_height] || 12, :ship_time => options[:ship_time] || skip_weekends(Time.now, 3.days), :package_count => options[:package_count] || 1)													
	    raise "unable to calculate shipping rates. please check your shipping address or call customer service to place an order." if @rates.blank?
	    @rates
	  end
		
		def cch_sales_tax(customer, options = {})
			Rails.logger.info "Getting CCH tax for #{customer.inspect}"
			options[:shipping_charge] ||= calculate_shipping(customer, options) #get_delayed_shipping
			options[:handling_charge] ||= calculate_handling
			options[:cart] ||= get_cart.reload
			options[:tax_exempt_certificate] ||= get_user.tax_exempt_certificate
			options[:exempt] ||= tax_exempt?
			options[:confirm_address] ||= false
			tries = 0
      begin
				tries += 1
      	@cch = CCH::Cch.new(:action => 'calculate', :cart => options[:cart], :confirm_address => options[:confirm_address],  :customer => customer, :handling_charge => options[:handling_charge], :shipping_charge => options[:shipping_charge], :exempt => options[:exempt], :tax_exempt_certificate => options[:tax_exempt_certificate])
      rescue Timeout::Error => e
				if tries < 4     
			    sleep(2**tries)            
			    retry                      
			  end
      	Rails.logger.error "!!! CCH Timed out. Retrying..."
      end
    end
    
    def tax_from_order(order, refund = false)
      if calculate_tax?(order.address.state)
        set_current_system order.system
        @cch = CCH::Cch.new(:action => refund ? 'ProcessAttributedReturn' : 'calculate', :customer => order.address, :shipping_charge => order.shipping_amount, :handling_charge => order.handling_amount, :total => order.subtotal_amount, :transaction_id => order.tax_transaction, :exempt => order.user.tax_exempt?, :tax_exempt_certificate => order.user.tax_exempt_certificate )
        order.update_attributes(:tax_transaction => @cch.transaction_id, :tax_calculated_at => Time.zone.now,  :tax_amount => @cch.total_tax, :tax_exempt => order.user.tax_exempt?, :tax_exempt_number => order.user.tax_exempt_certificate) if !refund && @cch && @cch.success? 
			end
    end
    
    def subtotal_cart
      gross_price get_cart.sub_total
    end
    
    def shipping_vat
      calculate_vat get_cart.shipping_amount
    end
    
    def total_cart
      (get_cart.sub_total + get_cart.tax_amount + get_cart.shipping_amount + calculate_handling + shipping_vat).round(2)
    end
    
    def calculate_tax?(state)
      %w(CA IN WA UT).include?(state)
    end
    
    def calculate_setup_fee(subtotal, shipping_and_handling, tax)
      total = subtotal + shipping_and_handling + tax
      monthly_payment = (subtotal/(Payment::NUMBER_OF_PAYMENTS + 1.0)).round(2)
      setup_fee = monthly_payment + shipping_and_handling + tax
      setup_fee += total - setup_fee - monthly_payment * Payment::NUMBER_OF_PAYMENTS
    end

		def process_card(options = {})
      amount, billing, order, tokenize_only = options[:amount], options[:payment], options[:order], options[:tokenize_only]
      get_gateway(options[:system])
      user = get_user unless options[:no_user]
      unless billing.use_saved_credit_card || options[:use_payment_token]
				card_name = correct_card_name(billing.card_name)
        credit_card = ActiveMerchant::Billing::CreditCard.new(:first_name => billing.first_name, :last_name => billing.last_name, :number => billing.full_card_number, :month => billing.card_expiration_month, :year => billing.card_expiration_year,
                          :type => card_name, :verification_value => billing.card_security_code, :start_month => billing.card_issue_month, :start_year => billing.card_issue_year, :issue_number => billing.card_issue_number)
        raise "Credit card is invalid. #{credit_card.errors.full_messages * ", "}" if !credit_card.valid?
      end
      if is_us?
        gw_options = {:email => billing.email, :order_id => order}
        gw_options[:billing_address] = {:company => billing.company, :phone => billing.phone,  :address1 => billing.address1, :city => billing.city, :state => billing.state, :country => billing.country, :zip => billing.zip_code} unless billing.use_saved_credit_card
      	gw_options[:subscription_id] = billing.subscriptionid
      	if billing.deferred
					gw_options[:setup_fee] = (calculate_setup_fee(get_cart.sub_total, get_cart.shipping_amount + calculate_handling, get_cart.tax_amount) * 100).round
					gw_options[:number_of_payments] = billing.number_of_payments
					gw_options[:frequency] = billing.frequency
					gw_options[:start_date] = 1.months.since.strftime("%Y%m%d")
					gw_options[:subscription_title] = "#{get_domain.capitalize} Three Easy Payments"
					amount = (billing.deferred_payment_amount * 100).round
				end
				gw_options[:customer_account_id] = user.erp == 'New' || user.erp.blank? ? user.id : user.erp if user.present? && (billing.deferred || billing.save_credit_card || tokenize_only)
			else
        gw_options = {
          :order_id => order,
          :address => {},
          :email => billing.email,
          :billing_address => {:name => billing.first_name + ' ' + billing.last_name, :address1 => billing.address1, :city => billing.city, :state => billing.state, :country => country_2_code(billing.country), :zip => billing.zip_code, :phone => billing.phone}
        }
        gw_options[:currency] = is_gbp? ? "GBP" : "EUR" 
      end
      amount_to_charge = tokenize_only ? 0 : amount.to_i #? amount : (total_cart * 100 ).to_i
			timeout(50) do
	      if options[:capture] && !billing.deferred && !billing.use_saved_credit_card && !billing.save_credit_card && !tokenize_only && !options[:use_payment_token]
					@net_response = @gateway.purchase(amount_to_charge, credit_card, gw_options)  
				elsif (billing.save_credit_card || tokenize_only) && !billing.use_saved_credit_card && !options[:use_payment_token]
				  gw_options.merge!(:number_of_payments => 0, :frequency=> "on-demand", :shipping_address => {}, :start_date => Time.zone.now.strftime("%Y%m%d"),  :subscription_title => "#{credit_card.first_name} #{credit_card.last_name}", :setup_fee => amount_to_charge)
				  @net_response = @gateway.recurring_billing(0, credit_card, gw_options)
				elsif (billing.use_saved_credit_card || options[:use_payment_token]) && !tokenize_only
				  Rails.logger.info "use_saved_credit_card: #{amount_to_charge}, #{gw_options}"
				  @net_response = @gateway.pay_on_demand amount_to_charge, gw_options
				elsif (billing.use_saved_credit_card || options[:use_payment_token]) && tokenize_only
				  @payment = billing
				  @payment.copy_common_attributes user.token unless options[:use_payment_token] || user.blank?
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
        @payment.paid_amount = amount ? amount/100.0 : total_cart
        @payment.vendor_tx_code = order
        @payment.mask_card_number
        if @payment.use_saved_credit_card && !options[:use_payment_token] && user.present? && user.token
          @payment.card_number = user.token.card_number
        	@payment.card_expiration_month = user.token.card_expiration_month
        	@payment.card_expiration_year = user.token.card_expiration_year
        	@payment.card_name = user.token.card_name
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
        raise 'Your card could not be authorized! Please correct any details below and try again, try another card or contact us for further assistance. ' + message.join("<br>")
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
        payment.save(:validate => false)
      end
      @net_response
    end
    
    def refund_cc_transaction(payment, options = {})
      get_gateway
      options.merge!(:order_id => "REFUND#{payment.order.id}", :description => "REFUND#{payment.order.id}", :currency => payment.order.locale.to_s == 'en-UK' ? "GBP" : "EUR") if is_uk?
      timeout(30) do
				@net_response = @gateway.credit(payment.paid_amount * 100, payment.authorization, options)
			end
      if @net_response.success?
        payment.refunded_at = Time.zone.now
        payment.refunded_amount = if @net_response.params['amount'].present?
            @net_response.params['amount'] 
          else
            payment.paid_amount
          end
        payment.refund_authorization = @net_response.authorization
        payment.status = "REFUND"
        payment.save(:validate => false)
      end
      @net_response
    end
    
    # example: tokenize_billing_info(credit_card, :billing_address=>{:address1 => @billing.address, :address2 => @billing.address2, :country => @billing.country, :company => @billing.company, :zip => @billing.zip_code, :phone => @billing.phone, :state => @billing.state, :city => @billing.city}, :email => @billing.email, :order_id => get_user.id, :customer_account_id => get_user.erp)
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
    
    # example: 
    #   tokenized_billing_info :subscription_id=>"2774176050310008284282", :order_id=>"aweweweqq"
    def delete_tokenized_billing_info(options)
      get_gateway options[:system]
      @gateway.delay.delete_customer_info options
    end
    
    # updates current user's payment/subscription token from cybersource
    def update_user_token
      if is_er_us? && get_user.token && !get_user.token.current?
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
	  	Country.name_2_code(country)
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

		
		def skip_weekends(date, inc)
		  date += inc
		  while (date.wday % 7 == 0) or (date.wday % 7 == 6) do
		    date += inc
		  end   
		  date
		end
		
		def new_payment(user = get_user)
  		@payment = Payment.new
  		@payment.copy_common_attributes(user.billing_address) if user.billing_address
  		@payment.use_saved_credit_card = true if is_er_us? && user.token && user.token.current?
  		@payment.attributes = params[:payment] if params[:payment]
  		raise "Purchase Order is missing" if @payment.purchase_order && @payment.purchase_order_number.blank?
  		@payment.subscriptionid = user.token.subscriptionid if is_er_us? && user.token && user.token.current?
  	end
  	
  	def can_use_previous_payment?
  	  !get_cart.order_reference.blank? && current_admin && current_admin.can_act_as_customer && Order.find(get_cart.order_reference).user == current_user rescue false
  	end
  	
  	def can_tokenize_payment?
  	  is_us? && !is_sizzix?
  	end
  	
  	def purchase_order_allowed?
  	  is_ee? || !is_sizzix? && user_signed_in? && get_user.purchase_order
  	end
  	
  	def tax_exempt?
  	  user_signed_in? && get_user.tax_exempt?
  	end
  	
  	def ecommerce_allowed?
  	  !is_er? || user_signed_in? && get_user.status == 'active'
  	end
  	
  	def cod_allowed?
  	  is_er?
  	end

    def retailer_discount_levels
      RetailerDiscountLevels.instance
    end
    
	end
	
	def self.included(receiver)
		receiver.extend         ClassMethods
		receiver.send :include, InstanceMethods
	end
end