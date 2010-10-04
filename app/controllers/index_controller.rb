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

	end
	
	def search
	  redirect_to :action => "catalog" and return unless request.xhr?
	  @facets = params[:facets] || ""
	  @facets_hash = @facets.split(",")
	  @breadcrumb_tags = Tag.any_of(*@facets_hash.map {|e| {:tag_type => e.split("~")[0], :permalink => e.split("~")[1]}}).cache unless @facets_hash.blank?
	  @search = Product.search do |query|
	    query.keywords params[:q] unless params[:q].blank?
	    query.with :"listable_#{current_system}", true
	    @facets_hash.each do |f|
	      query.with :"#{f.split("~")[0]}_#{current_system}", f
	    end
	    Tag::TYPES.each do |e|
    		query.facet :"#{e.to_s}_#{current_system}"
     	end
     	query.paginate(:page => params[:page] || 1, :per_page => 4)
     	query.order_by(*params[:sort].split(":")) unless params[:sort].blank?
	  end
	  @products = @search.results
	end
end
