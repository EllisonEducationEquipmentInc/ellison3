class IndexController < ApplicationController
	
	def home

	end
	
	def products
		@products = Product.send(current_system).active.all.paginate :page => params[:page], :per_page => 24
	end
	
	def product
		@product = Product.find(params[:id])
	rescue
		render :file => "#{Rails.root}/public/404_#{current_system}.html", :layout => false, :status => 404
	end
end
