class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout, :proceed_checkout]
	before_filter :authenticate_admin!, :only => [:custom_price]
	before_filter :trackable
	before_filter :no_cache, :only => [:checkout]
	after_filter(:only => [:checkout, :proceed_checkout]) {|controller| controller.send(:get_cart).reset_item_errors}
	
	ssl_required :checkout, :proceed_checkout
	ssl_allowed :index, :get_shipping_options, :change_shipping_method, :copy_shipping_address, :change_shipping_method, :get_shipping_service, :get_shipping_amount, :get_tax_amount, :get_total_amount,
	  :custom_price, :create_shipping, :create_billing, :activate_coupon, :remove_coupon
	
	verify :xhr => :true, :only => [:proceed_checkout, :get_shipping_options, :get_shipping_amount, :get_tax_amount, :get_total_amount, :activate_coupon, :remove_coupon], :redirect_to => {:action => :index}
	
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
		new_payment
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
		new_payment
	end
	
	def copy_shipping_address
		@billing_address = get_user.addresses.build(get_user.shipping_address.attributes)
		@billing_address.address_type = "billing"
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
		@order.save!
		@order.decrement_items!
		flash[:notice] = "Thank you for your order.  Below is your order receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		clear_cart
		UserMailer.order_confirmation(@order).deliver
		render "checkout_complete"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("\n")
		if @cart.cart_items.blank?
			flash[:alert] = @error_message
			render :js => "window.location.href = '#{products_path}'" and return
		end
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
	    @cart.apply_coupon_discount
	  else
	    render :js => "$('#coupon_form').resetForm();alert('Invalid Coupon Code: #{params[:coupon_code]}');" and return
	  end
	end
	
	def remove_coupon
	  get_cart.coupon = nil
	  @cart.apply_coupon_discount
	  @cart.save
	  render :activate_coupon
	end

private
	
	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
	end
end
