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
		redirect_to :action => "outlet", :anchor => "q=#{@product.item_num}" and return if !request.xhr? && is_sizzix_us? && @product && @product.outlet 
		if request.xhr?
      render :product_min, :layout => false and return 
  	else
		  fresh_when(:etag => [current_locale, current_system, @product, current_user, request.xhr?], :last_modified => @product.updated_at.utc)
		end
	rescue Exception => e
	  Rails.logger.info e.message
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
    fresh_when :etag => [current_locale, current_system, current_user, flash]
	end
	
	def outlet
	  @title = "Sizzix Outlet"
	end
	
	def search
    get_search(outlet?)
    session[:user_return_to] = (outlet? ? outlet_path : catalog_path) + "#" + request.env["QUERY_STRING"]
	  @products = @search.results
	end
	
	def quick_search
	  @landing_page = LandingPage.find params[:id]
	  params[:facets] = (params[:facets].split(",") << @landing_page.search_query).join(",")
	  get_search
	  render :partial => 'quick_search'
	end
	
private
  
  def get_search(outlet = false)
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
	    query.with :outlet, outlet
	    @facets_hash.each do |f|
	      query.with :"#{f.split("~")[0]}_#{current_system}", f
	    end
	    query.with(:"price_#{current_system}_#{current_currency}", params[:price].split("~")[0]..params[:price].split("~")[1]) unless params[:price].blank?
      query.with(:"saving_#{current_system}_#{current_currency}", params[:saving].split("~")[0]..params[:saving].split("~")[1]) unless params[:saving].blank?
	    tag_types.each do |e|
    		query.facet :"#{e.to_s}_#{current_system}"
     	end
     	query.facet(:price) do |qf|
	      PriceFacet.instance.facets(outlet).each do |price_range|
	        qf.row(price_range) do
            with(:"price_#{current_system}_#{current_currency}", price_range.min..price_range.max)
          end
	      end
      end
      if outlet
        query.facet(:saving) do |qf|
          PriceFacet.instance.savings.each do |saving|
            qf.row(saving) do
              with(:"saving_#{current_system}_#{current_currency}", saving.min..saving.max)
            end
          end
        end
      end
     	query.paginate(:page => params[:page] || 1, :per_page => 16)
     	query.order_by(*params[:sort].split(":")) unless params[:sort].blank?
	  end
  end
  
  # solr filter display logic
  def tag_types
    tags = Tag::TYPES - Tag::HIDDEN_TYPES
    tags -= ["release_date", "special"] unless ecommerce_allowed?
    tags
  end
end
