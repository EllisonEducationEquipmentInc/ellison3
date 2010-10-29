class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout, :proceed_checkout, :quote, :proceed_quote]
	before_filter :authenticate_admin!, :only => [:custom_price]
	before_filter :trackable
	before_filter :no_cache, :only => [:checkout, :quote]
	after_filter(:only => [:checkout, :proceed_checkout, :quote, :proceed_quote]) {|controller| controller.send(:get_cart).reset_item_errors}
	
	ssl_required :checkout, :proceed_checkout, :quote, :proceed_quote
	ssl_allowed :index, :get_shipping_options, :change_shipping_method, :copy_shipping_address, :change_shipping_method, :get_shipping_service, :get_shipping_amount, :get_tax_amount, :get_total_amount,
	  :custom_price, :create_shipping, :create_billing, :activate_coupon, :remove_coupon
	
	verify :xhr => true, :only => [:proceed_checkout, :get_shipping_options, :get_shipping_amount, :get_tax_amount, :get_total_amount, :activate_coupon, :remove_coupon, :proceed_quote], :redirect_to => {:action => :index}
	
	def index
		@title = "Shopping #{I18n.t(:cart).titleize}"
		get_cart
		render :index, :layout => false if request.xhr?
	end
		
	def add_to_cart
		add_2_cart(Product.find(params[:id]))
	end
	
	def remove_from_cart
		@cart_item_id = remove_cart(params[:item_num])
	end
	
	def empty_cart
		clear_cart
	end
	
	def checkout
    # get_cart.update_items true
    # flash[:alert] = ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
		redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
		@title = "Checkout"
		@cart_locked, @checkout = true, true
		unless get_user.billing_address && get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
			@billing_address = get_user.billing_address || get_user.addresses.build(:address_type => "billing", :email => get_user.email) 
		end
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
		new_payment
		@payment.use_saved_credit_card = true if get_user.token && get_user.token.current?
		expires_now
	end
	
	def quote
	  redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !(quote_allowed? || get_cart.pre_order?)
		@title = quote_name
		@cart_locked, @checkout = true, true
		unless get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
		end
	end
	
	# TODO: DRY order setters
	def quote_2_order
	  @quote = get_user.quotes.active.where(:system => current_system, :_id => BSON::ObjectId(params[:id])).first
	  redirect_to root_url and return unless get_user.billing_address && @quote && request.xhr? && request.post?
	  render :js => "window.location.href = '#{myquote_path(@quote)}'" and return unless @quote.can_be_converted?
  	new_payment
		@payment.attributes = params[:payment]
		@order = Order.new
		@order.copy_common_attributes @quote
		@order.order_items = @quote.order_items
		process_card(:amount => (get_cart.total * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true)
		@order.payment = @payment
		@order.address = get_user.shipping_address.clone
		@order.user = get_user
		@order.ip_address = request.remote_ip
		@order.status = "Open"
		@order.comments = params[:comments]
		if admin_signed_in?
		  @order.customer_rep = current_admin.name
		  @order.customer_rep_id = current_admin.id
		end
		if @payment.save_credit_card
		  get_user.token = Token.new :last_updated => Time.zone.now, :status => "CURRENT"
		  get_user.token.copy_common_attributes @payment, :status
		  get_user.save
		end
		@order.save!
		@quote.update_attributes :active => false
		@order.decrement_items!
		flash[:notice] = "Thank you for your order.  Below is your order receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		UserMailer.order_confirmation(@order).deliver
		render "checkout_complete"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("<br />")
	end
		
	def proceed_checkout
	  redirect_to :checkout and return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		get_cart.update_items true
		raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
		new_payment
		@payment.attributes = params[:payment]
		cart_to_order(:address => get_user.shipping_address)
		process_card(:amount => (get_cart.total * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true)
		@order.payment = @payment
		@order.address = get_user.shipping_address.clone
		@order.user = get_user
		@order.ip_address = request.remote_ip
		@order.status = "Open"
		@order.comments = params[:comments]
		if admin_signed_in?
		  @order.customer_rep = current_admin.name
		  @order.customer_rep_id = current_admin.id
		end
		if @payment.save_credit_card
		  get_user.token = Token.new :last_updated => Time.zone.now, :status => "CURRENT"
		  get_user.token.copy_common_attributes @payment, :status
		  get_user.save
		end
		@order.save!
		@order.decrement_items!
		flash[:notice] = "Thank you for your order.  Below is your order receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		clear_cart
		UserMailer.order_confirmation(@order).deliver
		render "checkout_complete"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("<br />")
		if @cart.cart_items.blank?
			flash[:alert] = @error_message
			render :js => "window.location.href = '#{catalog_path}'" and return
		end
	end
	
	def proceed_quote
	  redirect_to :quote and return unless (quote_allowed? || get_cart.pre_order?) && get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
	  get_cart.update_items true, true
    raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
	  cart_to_quote(:address => get_user.shipping_address)
	  @quote.address = get_user.shipping_address.clone
		@quote.user = get_user
		@quote.ip_address = request.remote_ip
		@quote.comments = params[:comments]
		if admin_signed_in?
		  @quote.customer_rep = current_admin.name
		  @quote.customer_rep_id = current_admin.id
		end
		@quote.save!
	  flash[:notice] = "Thank you for your #{quote_name}.  Below is your #{quote_name} receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		clear_cart
	  UserMailer.quote_confirmation(@quote).deliver
	  render :js => "window.location.href = '#{myquote_path(@quote)}'"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message
		if get_cart.cart_items.blank?
			flash[:alert] = @error_message
			render :js => "window.location.href = '#{catalog_path}'" and return
		end
		render :proceed_checkout
	end
	
	def create_shipping
		get_cart.reset_tax_and_shipping(true)
		@shipping_address = get_user.addresses.build(:address_type => "shipping")
		@shipping_address.attributes = params[:shipping_address]
		@billing_address = get_user.addresses.build(:address_type => "billing", :email => get_user.email)
	end
	
	def create_billing
		@billing_address = get_user.addresses.build(:address_type => "billing")
		@billing_address.attributes = params[:billing_address]
		@quote = params[:quote] unless params[:quote].blank?
		new_payment
	end
	
	def copy_shipping_address
		@billing_address = get_user.addresses.build(get_user.shipping_address.attributes)
		@billing_address.address_type = "billing"
	end
	
	def forget_credit_card
	  get_user.token.delete
	  new_payment
	end
	
	def change_shipping_method
		@rate = get_cart.shipping_rates.detect {|r| r['type'] == params[:method]}
		get_cart.update_attributes :shipping_amount => @rate['rate'], :shipping_service => @rate['type']
	rescue
		calculate_shipping(get_user.shipping_address, :shipping_service => params[:method])
	end
	
	def get_shipping_options
		return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		render :partial => 'shipping_options'
	end
	
	def get_shipping_service
		render :text => get_cart.shipping_service.try(:humanize)
	end
	
	def get_shipping_amount
		return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		render :inline => "<%= number_to_currency calculate_shipping(get_user.shipping_address) %>"
	end
	
	def get_tax_amount
		return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		render :inline => "<%= number_to_currency calculate_tax(get_user.shipping_address) %>"
	end
	
	def get_total_amount
		return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		tries = 0
		begin
			tries += 1
			@total = get_cart.reload.total
		rescue Exception => e
			Rails.logger.error e
			if tries < 15        
		    sleep(tries)            
		    retry                      
		  end
		end
		render :inline => "<%= number_to_currency @total %>"
	end
	
	def custom_price
	  render :nothing => true and return unless current_admin.can_change_prices
	  @cart_item = get_cart.cart_items.find(params[:element_id].gsub("cart_item_price_", ""))
	  @cart_item.update_attributes(:price => params[:update_value][/[0-9.]+/], :custom_price => true)
	  render :inline => "<%= display_product_price_cart @cart_item %>"
	end
	
	def activate_coupon
	  @coupon = Coupon.available.where(:codes.in => [params[:coupon_code]]).first
	  if @coupon
	    get_cart.coupon = @coupon
	    @cart.reset_tax_and_shipping
	    @cart.apply_coupon_discount
	  else
	    render :js => "$('#coupon_form').resetForm();alert('Invalid Coupon Code: #{params[:coupon_code]}');" and return
	  end
	end
	
	def remove_coupon
	  get_cart.coupon = nil
	  @cart.reset_tax_and_shipping
	  @cart.apply_coupon_discount
	  render :activate_coupon
	end

private
	
	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
	end
end
