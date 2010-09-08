class CartsController < ApplicationController
	before_filter :authenticate_user!, :only => [:checkout]
	
	def index
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
		@title = "Checkout"
		@cart_locked = true
		unless get_user.billing_address && get_user.shipping_address
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping", :email => get_user.email) 
			@billing_address = get_user.billing_address || get_user.addresses.build(:address_type => "billing", :email => get_user.email) 
		end
		new_payment
		redirect_to(products_path, :alert => I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
	end
	
	def create_shipping
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
		new_payment
		@payment.attributes = params[:payment]
		process_card(:amount => (get_cart.sub_total * 100).round, :payment => @payment, :order => rand(10000), :capture => true)
		clear_cart
		render :js => "window.location.href = '#{order_confirmation_path}'"
	rescue Exception => e
		@error_message = e.message
	end
	
	def order_confirmation
		render :text => "TODO: order confirmation..."
	end

private
	
	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
	end
end
