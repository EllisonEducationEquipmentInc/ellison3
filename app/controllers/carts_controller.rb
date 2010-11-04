class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout, :proceed_checkout, :quote, :proceed_quote, :quote_2_order]
	before_filter :authenticate_admin!, :only => [:custom_price]
	before_filter :admin_user_as_permissions!, :only => [:remove_order_reference, :use_previous_orders_card]
	before_filter :trackable
	before_filter :no_cache, :only => [:checkout, :quote]
	after_filter(:only => [:checkout, :proceed_checkout, :quote, :proceed_quote]) {|controller| controller.send(:get_cart).reset_item_errors}
	
	ssl_required :checkout, :proceed_checkout, :quote, :proceed_quote
	ssl_allowed :index, :get_shipping_options, :change_shipping_method, :copy_shipping_address, :change_shipping_method, :get_shipping_service, :get_shipping_amount, :get_tax_amount, :get_total_amount,
	  :custom_price, :create_shipping, :create_billing, :activate_coupon, :remove_coupon
	
	verify :xhr => true, :only => [:proceed_checkout, :get_shipping_options, :get_shipping_amount, :get_tax_amount, :get_total_amount, :activate_coupon, :remove_coupon, :proceed_quote, :quote_2_order, :use_previous_orders_card, :remove_order_reference], :redirect_to => {:action => :index}
	
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
    session[:user_return_to] = nil
		redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
		@title = "Checkout"
		@cart_locked, @checkout = true, true
		unless get_user.billing_address && get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
			@billing_address = get_user.billing_address || get_user.addresses.build(:address_type => "billing", :email => get_user.email) 
		end
    update_user_token
		new_payment
		expires_now
	end
	
	def quote
	  session[:user_return_to] = nil
	  redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !(quote_allowed? || get_cart.pre_order?)
		@title = quote_name
		@cart_locked, @checkout = true, true
		unless get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
		end
	end
	
	def quote_2_order
	  @quote = get_user.quotes.active.where(:system => current_system, :_id => BSON::ObjectId(params[:id])).first
	  redirect_to root_url and return unless get_user.billing_address && @quote && request.xhr? && request.post?
	  unless @quote.can_be_converted?
	    flash[:alert] = "Your quote cannot be converted to an order this time. Please try again later."
	    render :js => "window.location.href = '#{myquote_path(@quote)}'" and return
	  end
  	new_payment
		@order = Order.new
		@order.copy_common_attributes @quote, :created_at
		@order.order_items = @quote.order_items
		process_card(:amount => (@quote.total_amount * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true, :tokenize_only => !payment_can_be_run?)
		@order.payment = @payment
		@order.quote = @quote
		process_order @order
		@quote.update_attributes :active => false
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
		if can_use_previous_payment? && params[:payment] && params[:payment][:use_previous_orders_card] 
      @payment = Order.find(get_cart.order_reference).payment.dup
      use_payment_token = true
		else
		  use_payment_token = false
		  new_payment
		end
		cart_to_order(:address => get_user.shipping_address)
    process_card(:amount => (get_cart.total * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true, :tokenize_only => !payment_can_be_run?, :use_payment_token => use_payment_token)
		@order.payment = @payment
    process_order(@order)
		clear_cart
		UserMailer.order_confirmation(@order).deliver
		render "checkout_complete"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("<br />")
		if get_cart.cart_items.blank?
			flash[:alert] = @error_message
			render :js => "window.location.href = '#{catalog_path}'" and return
		end
	end
	
	def proceed_quote
	  redirect_to :quote and return unless (quote_allowed? || get_cart.pre_order?) && get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
	  get_cart.update_items true, true
    raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
	  cart_to_quote(:address => get_user.shipping_address)
    process_order @quote
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
	  @quote = params[:quote] unless params[:quote].blank?
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

  def remove_order_reference
    get_cart.update_attributes :order_reference => nil
    render :js => "$('#previous_order_reference').remove()"
  end
  
  def use_previous_orders_card
    new_payment
    render :partial => "payment"
  end
  
private
	

end
