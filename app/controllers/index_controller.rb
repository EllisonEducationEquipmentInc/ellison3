class IndexController < ApplicationController
	
	def home

	end
	
	def products
		@products = Product.send(current_system).active.all.paginate :page => params[:page], :per_page => 24
	end
end
