class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout]
	after_filter(:only => [:checkout, :proceed_checkout]) {|controller| controller.send(:get_cart).reset_item_errors}
	
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
		get_cart.update_items true
		flash[:alert] = ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
		redirect_to(products_path, :alert => flash[:alert] || I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
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
		get_cart.update_items true
		raise RealTimeCartError, ("<strong>Please note:</strong> " + @cart.cart_errors.join("<br />")).html_safe unless @cart.cart_errors.blank?
		new_payment
		@payment.attributes = params[:payment]
		cart_to_order(:address => get_user.shipping_address)
		process_card(:amount => (get_cart.total * 100).round, :payment => @payment, :order => @order.id, :capture => true)
		@order.payment = @payment
		@order.address = get_user.shipping_address.clone
		@order.user = get_user
		@order.ip_address = request.remote_ip
		@order.status = "Open"
		@order.save!
		@order.decrement_items!
		flash[:notice] = "Thank you for your order.  Below is your order receipt.  Please print it for your reference.  You will also receive a copy of this receipt by email."
		clear_cart
		render :js => "window.location.href = '#{order_path(@order)}'"
	rescue Exception => e
		@reload_cart = @cart_locked = true if e.exception.class == RealTimeCartError
		@error_message = e.message #backtrace.join("\n")
		if @cart.cart_items.blank?
			flash[:alert] = @error_message
			render :js => "window.location.href = '#{products_path}'" and return
		end
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

private
	
	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
	end
end
