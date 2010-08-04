class IndexController < ApplicationController
	
	def home

	end
	
	def products
		@products = Product.send(current_system).active.all.paginate :page => params[:page], :per_page => 24
	end
	
	def product
		@product = Product.find(params[:id])
	end
end
