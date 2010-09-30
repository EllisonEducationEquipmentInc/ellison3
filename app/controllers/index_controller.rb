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
		@product = Product.send(current_system).criteria.id(params[:id]).first
		raise "Invalid product" unless @product.displayable?
		@title = @product.name
	rescue
		go_404
	end
	
	def catalog
	  @search = Product.search do |query|
	    query.with :"listable_#{current_system}", true
	    Tag::TYPES.each do |e|
    		query.facet :"#{e.to_s.pluralize}_#{current_system}"
     	end
     	query.paginate(:page => 1, :per_page => 24)
	  end
	  @products = @search.results
	end
end
