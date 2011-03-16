class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout, :proceed_checkout, :quote, :proceed_quote, :quote_2_order, :move_to_cart, :delete_from_saved_list, :save_cod]
	before_filter :authenticate_admin!, :only => [:custom_price]
	before_filter :admin_user_as_permissions!, :only => [:remove_order_reference, :use_previous_orders_card]
	before_filter :trackable
	before_filter :store_path!
	before_filter :no_cache, :only => [:checkout, :quote]
	before_filter :set_vat_exempt, :except => [:add_to_cart, :index, :move_to_cart, :remove_from_cart, :change_quantity, :delete_from_saved_list, :saved_list]
	after_filter(:only => [:checkout, :proceed_checkout, :quote, :proceed_quote]) {|controller| controller.send(:get_cart).reset_item_errors}
	
	ssl_required :checkout, :proceed_checkout, :quote, :proceed_quote
	ssl_allowed :index, :get_shipping_options, :change_shipping_method, :copy_shipping_address, :change_shipping_method, :get_shipping_service, :get_shipping_amount, :get_tax_amount, :get_total_amount,
	  :custom_price, :create_shipping, :create_billing, :activate_coupon, :remove_coupon, :shopping_cart, :change_quantity, :add_selected_to_cart, :move_to_cart, :delete_from_saved_list, :last_item,
	   :add_to_cart, :remove_from_cart, :save_cod
	
	verify :xhr => true, :only => [:get_shipping_options, :get_shipping_amount, :get_tax_amount, :get_total_amount, :activate_coupon, :remove_coupon, :proceed_quote, :use_previous_orders_card, :remove_order_reference, :shopping_cart, :change_quantity, :add_selected_to_cart, :save_cod], :redirect_to => {:action => :index}
	
	def index
	  if get_cart.last_check_at.blank? || get_cart.last_check_at.present? && get_cart.last_check_at.utc < 5.minute.ago.utc
	    return unless real_time_cart
	  end
		@title = "Shopping #{I18n.t(:cart).titleize}"
		@cart_locked = true if params[:locked] == "1"
		@shared_content = SharedContent.cart
		render :index, :layout => false if request.xhr?
	end
	
	def last_item
	  render :last_item, :layout => false
	end
		
	def add_to_cart
	  add_to_cart_do
	end
	
	def move_to_cart
	  add_to_cart_do
    remove_from_saved_list
	end
	
	def delete_from_saved_list
	  remove_from_saved_list
	  render :move_to_cart
	end
	
	def add_selected_to_cart
	  render :nothing => true and return if params[:values].blank? || !ecommerce_allowed?
	  params[:values].split(",").each do |element|
	    item_id, qty = element.split(":")
	    @product = Product.find(item_id)
	    qty = qty.to_i
  	  qty = @product.minimum_quantity if is_er? && qty < @product.minimum_quantity
  		add_2_cart(@product, qty)
	  end
	  render :add_to_cart
	end
	
	def remove_from_cart
		@cart_item_id = remove_cart(params[:item_num])
	end
	
	def change_quantity
	  qty = params[:qty].to_i
	  if qty < 1
	    @cart_item_id = remove_cart(params[:item_num])
	    render :remove_from_cart and return
	  else
	    @cart_item = change_qty(params[:item_num], qty)
	  end
	end
	
	def empty_cart
		clear_cart
	end
	
	def checkout
	  return unless real_time_cart
    session[:user_return_to] = nil
		redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !ecommerce_allowed?
		set_proper_currency!
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
	  redirect_to(catalog_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank? || !ecommerce_allowed? || !(quote_allowed? || get_cart.pre_order?)
		@title = quote_name
		@cart_locked, @checkout = true, true
		unless get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
		end
	end
	
	def quote_2_order
	  @quote = get_user.quotes.active.where(:system => current_system, :_id => BSON::ObjectId(params[:id])).first
	  redirect_to root_url and return unless get_user.billing_address && @quote && request.post?
	  unless @quote.can_be_converted?
	    flash[:alert] = "Your quote cannot be converted to an order this time. Please try again later."
	    render :js => "window.location.href = '#{myquote_path(@quote)}'" and return
	  end
  	new_payment
		@order = Order.new
		@order.copy_common_attributes @quote, :created_at
		@order.order_items = @quote.order_items
		process_card(:amount => (@quote.total_amount * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true, :tokenize_only => !payment_can_be_run?) unless @payment.purchase_order && purchase_order_allowed?
		@order.payment = @payment
		@order.quote = @quote
		@order.address ||= get_user.shipping_address.clone
		process_order @order
		@quote.update_attributes :active => false
		UserMailer.order_confirmation(@order).deliver
		@order.payment.save
		tax_from_order(@order)
		render "checkout_complete"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("<br />")
	end
		
	def proceed_checkout
	  redirect_to :checkout and return unless get_user.shipping_address && !get_cart.cart_items.blank?
		return unless real_time_cart
		if can_use_previous_payment? && params[:payment] && params[:payment][:use_previous_orders_card] 
      @payment = Order.find(get_cart.order_reference).payment.dup
      use_payment_token = true
		else
		  use_payment_token = false
		  new_payment
		end
		@payment.deferred = false if @payment.present? && !get_cart.allow_deferred?
		if @payment.try :deferred
		  @payment.number_of_payments = Payment::NUMBER_OF_PAYMENTS
			@payment.frequency = Payment::FREQUENCY
			@payment.deferred_payment_amount = (gross_price(get_cart.sub_total)/(@payment.number_of_payments + 1.0)).round(2)
		end
		cart_to_order(:address => get_user.shipping_address)
    process_card(:amount => (total_cart * 100).round, :payment => @payment, :order => @order.id.to_s, :capture => true, :tokenize_only => !payment_can_be_run?, :use_payment_token => use_payment_token) unless @payment.purchase_order && purchase_order_allowed? || get_cart.pre_order?
		@order.payment = @payment unless get_cart.pre_order?
    process_order(@order)
		clear_cart
		UserMailer.order_confirmation(@order).deliver
		@order.payment.try :save
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
	  return unless real_time_cart(true)
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
		get_cart.reset_tax
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
		calculate_shipping(get_user.shipping_address)
		render :inline => "<%= number_to_currency gross_price(get_cart.shipping_amount) %>"
	rescue Exception => e
	  Rails.logger.error e.backtrace.join("\n")
	  render :js => "alert('#{e}');"
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
			@total = total_cart
		rescue Exception => e
			Rails.logger.error e #.backtrace.join("\n")
			if tries < 15        
		    sleep(tries)            
			  get_cart.reload
		    retry                      
		  end
		end
		render :inline => "<%= number_to_currency @total %>"
	end
	
	def get_deferred_first_payment
	  return unless get_user.shipping_address && !get_cart.cart_items.blank? && request.xhr?
		tries = 0
		begin
			tries += 1
			@first_payment = calculate_setup_fee(total_cart, get_delayed_shipping + calculate_handling, get_cart.tax_amount)
		rescue Exception => e
			Rails.logger.error e #.backtrace.join("\n")
			if tries < 15        
		    sleep(tries)            
			  get_cart.reload
		    retry    
		  end
		end
		render :inline => "<%= number_to_currency @first_payment %>"
	end
	
	def custom_price
	  render :nothing => true and return unless current_admin.can_change_prices
	  @cart_item = get_cart.cart_items.find(params[:element_id].gsub("cart_item_price_", ""))
	  @cart_item.update_attributes(:price => params[:update_value][/[0-9.]+/], :custom_price => true)
	  render :inline => "<%= display_product_price_cart @cart_item %>"
	end
	
	def activate_coupon
	  coupon_code = params[:coupon_code].gsub(/[^a-zA-Z0-9]/, '')
	  @coupon = Coupon.available.with_coupon.where(:codes.in => [/^#{coupon_code}$/i]).first
	  if @coupon
	    get_cart.coupon = @coupon
	    @cart.coupon_code = coupon_code
	    @cart.reset_tax_and_shipping
	    @cart.apply_coupon_discount
	  else
	    render :js => "$('#coupon_form').resetForm();alert('Invalid Coupon Code: #{params[:coupon_code]}');" and return
	  end
	end
	
	def remove_coupon
	  get_cart.coupon_id, get_cart.coupon_code = nil
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
  
  def shopping_cart
    render :partial => "carts/shopping_cart"
  end
  
  def save_cod
	  if params[:cod_account_type].blank? || params[:cod_account].blank?
	    render :js => "alert('COD account type and COD account # fields are required');"
	  else
	    @user = get_user
	    @user.cod_account_type = params[:cod_account_type]
	    @user.cod_account = params[:cod_account]
	    @user.save(:validate => false)
	    get_cart.reset_tax_and_shipping true
	    render :action => 'carts/change_shipping_method'
	  end
	end
  
private

  def real_time_cart(quote = false)
    get_cart.update_items true, quote
    flash[:alert] = ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
    # raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
    if request.xhr?
      render :js => "window.location.href = '#{cart_path}'" and return false if @cart.cart_errors.present?
    else
      redirect_to(cart_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return false if @cart.cart_errors.present?
    end
    true
  end
	
	def add_to_cart_do
	  @product = Product.available.find(params[:id])
	  qty = params[:qty].blank? ? is_er? ? @product.minimum_quantity : 1 : params[:qty].to_i
	  qty = @product.minimum_quantity if is_er? && qty < @product.minimum_quantity
		add_2_cart(@product, qty)
	end
	
	def remove_from_saved_list
	  @list = get_user.save_for_later_list
	  @list.product_ids.delete_if {|e| e.to_s == params[:id]}
	  @list.save
	end

end
