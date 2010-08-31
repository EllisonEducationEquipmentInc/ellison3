class IndexController < ApplicationController
	
	def test
		render :text => "text to render..."
	end
	
	def home

	end
	
	def products
		@products = Product.send(current_system).available.all.paginate :page => params[:page], :per_page => 24
	end
	
	def product
		@product = Product.find(params[:id])
	rescue
		go_404
	end
end
