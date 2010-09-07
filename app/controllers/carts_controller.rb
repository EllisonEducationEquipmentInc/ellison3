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
			@shipping_address = get_user.shipping_address || get_user.addresses.build(:address_type => "shipping") 
			@billing_address = get_user.billing_address || get_user.addresses.build(:address_type => "billing") 
		end
		new_payment
		redirect_to(products_path, :alert => I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
	end
	
	def create_shipping
		@shipping_address = get_user.addresses.build(:address_type => "shipping")
		@shipping_address.attributes = params[:shipping_address]
		@billing_address = get_user.addresses.build(:address_type => "billing")
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

private
	
	def new_payment
		@payment = Payment.new
		@payment.attributes = get_user.billing_address.attributes if get_user.billing_address
	end
end
