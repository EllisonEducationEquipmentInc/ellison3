class CartsController < ApplicationController
	
	def index
		# render @cart.cart_items
		render :index, :layout => false
	end
		
	def add_to_cart
		add_2_cart(Product.find(params[:id]))
	end
	
	def remove_from_cart
		@cart_item_id = remove_cart(params[:item_num])
	end
	
	def empty_cart
		clear_cart
		redirect_to :controller => "index", :action => "products"
	end
	
end
