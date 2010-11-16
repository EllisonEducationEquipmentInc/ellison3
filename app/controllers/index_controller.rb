class IndexController < ApplicationController
	
	before_filter :trackable, :except => [:catalog]
  before_filter :store_path!
	
	verify :xhr => true, :only => [:search, :quick_search], :redirect_to => {:action => :home}
		
	def home

	end
	
	def products
		@products = Product.send(current_system).available.all.paginate :page => params[:page], :per_page => 24
	end
	
	def product
		@product = Product.send(current_system).criteria.id(params[:id]).first
		raise "Invalid product" unless @product.displayable?
		@title = @product.name
		#fresh_when(:etag => [current_locale, current_system, @product, current_user], :last_modified => @product.updated_at.utc)
	rescue
		go_404
	end
	
	def shop
	  @landing_page = LandingPage.find params[:id]
	  params[:facets] = @landing_page.search_query
	  params[:sort] = "start_date_#{current_system}:desc"
	  get_search
	  @products = @search.results
	  fresh_when(:etag => [current_locale, current_system, @landing_page], :last_modified => @landing_page.updated_at.utc)
	end
	
	def catalog
    @title = "Catalog"
    #expires_in 3.hours, 'max-stale' => 5.hours
    fresh_when :etag => [current_locale, current_system, current_user]
	end
	
	def search
    get_search
    session[:user_return_to] = catalog_path + "#" + request.env["QUERY_STRING"]
	  @products = @search.results
	end
	
	def quick_search
	  @landing_page = LandingPage.find params[:id]
	  params[:facets] = (params[:facets].split(",") << @landing_page.search_query).join(",")
	  get_search
	  render :partial => 'quick_search'
	end
	
private
  
  def get_search
    # TODO: move price ranges to a class 
	  @price_ranges = is_ee? ? [["under", 20], ["under", 60], ["under", 100], ["under", 150], ["under", 300], ["under", 600], ["over", 600]] : [["under", 5], ["under", 10], ["under", 15], ["under", 25], ["under", 50], ["over", 50]]
	  @facets = params[:facets] || ""
	  @facets_hash = @facets.split(",")
	  @breadcrumb_tags = @facets_hash.blank? ? [] : Tag.any_of(*@facets_hash.map {|e| {:tag_type => e.split("~")[0], :permalink => e.split("~")[1]}}).cache 
	  @search = Product.search do |query|
	    query.keywords params[:q] unless params[:q].blank?
	    query.adjust_solr_params do |params|
        params[:"spellcheck"] = true
				params[:"spellcheck.collate"] = true
			end
	    query.with :"listable_#{current_system}", true
	    @facets_hash.each do |f|
	      query.with :"#{f.split("~")[0]}_#{current_system}", f
	    end
	    query.with(:"price_#{current_system}_#{current_currency}").send(params[:price].split("~")[0] == "under" ? :less_than : :greater_than, params[:price].split("~")[1]) unless params[:price].blank?
	    Tag::TYPES.each do |e|
    		query.facet :"#{e.to_s}_#{current_system}"
     	end
     	query.facet(:price) do |qf|
	      @price_ranges.each do |price_range|
	        qf.row(price_range) do
            with(:"price_#{current_system}_#{current_currency}").send(price_range[0] == "under" ? :less_than : :greater_than, price_range[1])
          end
	      end
      end
     	query.paginate(:page => params[:page] || 1, :per_page => 16)
     	query.order_by(*params[:sort].split(":")) unless params[:sort].blank?
	  end
  end
end
