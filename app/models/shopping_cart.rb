module ShoppingCart
	module ClassMethods
		
	end
	
	module InstanceMethods
		def get_cart
      @cart ||= (Cart.find(session[:shopping_cart]) rescue Cart.new)
    end
		
		def add_2_cart(product, qty = 1)
			if item = get_cart.cart_items.find_item(product.item_num)
				item.quantity += qty
			else
				get_cart.cart_items << CartItem.new(:name => product.name, :item_num => product.item_num, :sale_price => product.sale_price, :msrp => product.msrp, :price => product.price, :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product_id => product.id)
			end
			get_cart.save
			session[:shopping_cart] ||= get_cart.id.to_s
		end
		
		def remove_cart(item_num)
			cart_item = get_cart.cart_items.find_item(item_num)
			cart_item.delete
			get_cart.save
			cart_item.id.to_s
		end
		
		def clear_cart
			get_cart.clear
			session[:shopping_cart], @cart = nil
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
        gw_options = {
          :email => billing.email,
          :order_id => order,
        }
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
			SystemTimer.timeout_after(50) do
	      if options[:capture] && !billing.deferred && !billing.use_saved_credit_card
					@net_response = @gateway.purchase(amount_to_charge, credit_card, gw_options)  
					Rails.logger.warn "purchase #{gw_options.inspect}"
				elsif billing.use_saved_credit_card
				  @net_response = @gateway.pay_on_demand amount_to_charge, gw_options
				  logger.info "on-demand: #{@net_response.inspect}"
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
					SystemTimer.timeout_after(50) do
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
		
		def process_gw_response(response)
      if is_us?
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
                   :name => 'protx',
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

		class Config
	    attr_reader :name
	    attr_reader :user_name
	    attr_reader :password
	    def initialize(config)
	      #config = YAML::load(File.open("#{RAILS_ROOT}/vendor/plugins/minimalcart/config/#{ENV['system'] == "ellison_retailers" || ENV['system'] == "ellison_education" ? 'config_er' : 'config'}.yml"))
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