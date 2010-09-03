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
		redirect_to(products_path, :alert => I18n.t(:empty_cart)) and return if get_cart.cart_items.blank?
	end
	
end
