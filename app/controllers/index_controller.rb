class IndexController < ApplicationController
  
  before_filter :trackable, :except => [:catalog]
  before_filter :store_path!
  
  ssl_required :contact, :send_feedback
  
  verify :xhr => true, :only => [:search, :quick_search, :send_feedback, :add_comment], :redirect_to => {:action => :home}
    
  helper_method :idea?, :per_page
  
  def home

  end
  
  def products
    @products = Product.send(current_system).available.all.paginate :page => params[:page], :per_page => 24
  end
  
  def product
    @product = Product.send(current_system).find(params[:id])
    raise "Invalid product" unless @product.displayable?
    @title = @product.name
    #redirect_to :action => "outlet", :anchor => "q=#{@product.item_num}" and return if !request.xhr? && is_sizzix_us? && @product && @product.outlet 
    if request.xhr?
      render :product_min, :layout => false and return 
    else
      fresh_when(:etag => [current_locale, current_system, @product, current_user, request.xhr?], :last_modified => @product.updated_at.utc)
    end
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  def idea
    @idea = Idea.send(current_system).criteria.id(params[:id]).first
    raise "Invalid idea" unless @idea.listable?
    @title = @idea.name
    fresh_when(:etag => [current_system, @idea], :last_modified => @idea.updated_at.utc)
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  # landing page
  def shop
    @landing_page = LandingPage.send(current_system).available.find params[:id]
    params[:facets] = @landing_page.search_query
    params[:outlet] = "1" if @landing_page.outlet
    params[:sort] = "start_date_#{current_system}:desc"
    @title = @landing_page.name
    get_search
    @products = @search.results
    fresh_when(:etag => [current_locale, current_system, @landing_page], :last_modified => @landing_page.updated_at.utc)
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  # /lp/:id
  def tag_group
    if %w(product_lines artists themes designers categories curriculums).include? params[:id]
      get_search_objects
      @search = perform_search(@klass, :facets => [params[:id].singularize], :facet_sort => :index)
		else
			raise "invalid tag_type: #{params[:id]}"
		end
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  def catalog
    @title = "Catalog"
    #expires_in 3.hours, 'max-stale' => 5.hours
    fresh_when :etag => [current_locale, current_system, current_user, flash]
  end
  
  def outlet
    @title = "Outlet"
  end
  
  def search
    get_search
    session[:user_return_to] = catalog_path + "#" + request.env["QUERY_STRING"]
    @products = @search.results
    expires_in 1.hours, 'max-stale' => 1.hours
  end
  
  def quick_search
    @landing_page = LandingPage.find params[:id]
    params[:facets] = (params[:facets].split(",") << @landing_page.search_query).join(",")
    params[:outlet] = "1" if @landing_page.outlet
    get_search
    render :partial => 'quick_search'
  end
  
  def contact
    @feedback = Feedback.new
    @feedback.email = get_user.email if user_signed_in?
  end
  
  def send_feedback
    @feedback = Feedback.new(params[:feedback])
    @feedback.department = Feedback::DEPARTMENTS[0]
    @feedback.expires_at = 7.days.since
    @feedback.user = get_user if user_signed_in?
    @feedback.comments.first.email ||= @feedback.email
  end
  
  def reply_to_feedback
    @feedback = Feedback.find(params[:id])
    raise "wrong system" unless @feedback.system == current_system
  rescue 
    go_404
  end
  
  def add_comment
    @feedback = Feedback.find(params[:id])
    @comment = @feedback.comments.build params[:comment]
    @comment.email = @feedback.email
    @feedback.status = "New"
  end
  
  def limited_search
    get_search_objects
    @per_page = params[:per_page] if params[:per_page].to_i > 0
    @search = perform_search(@klass, :outlet => outlet?)
    @items = @search.results
    render :layout => false
  end
  
  def twitter_feed
    @feed = Feed.where(:name => 'twitter').first || Feed.new(:name => 'twitter')
    process_feed("http://twitter.com/statuses/user_timeline/46690271.rss")
    expires_in 3.minutes, 'max-stale' => 3.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def blog_feed
    @feed = Feed.where(:name => 'blog').first || Feed.new(:name => 'blog')
    process_feed("http://sizzixblog.blogspot.com/feeds/posts/default?alt=rss")
    expires_in 3.minutes, 'max-stale' => 3.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end

  def twitter_feed_uk
    @feed = Feed.where(:name => 'twitter_uk').first || Feed.new(:name => 'twitter_uk')
    process_feed("http://twitter.com/statuses/user_timeline/45567009.rss")
    expires_in 3.minutes, 'max-stale' => 3.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def blog_feed_uk
    @feed = Feed.where(:name => 'blog_uk').first || Feed.new(:name => 'blog_uk')
    process_feed("http://www.dacio.us/feed/")
    expires_in 3.minutes, 'max-stale' => 3.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def static_page
    @static_page = StaticPage.active.where(:system_enabled => current_system, :permalink => params[:id]).first
    raise "Invalid StaticPage" unless @static_page.present?
    @title = @static_page.name
    expires_in 1.hours, 'max-stale' => 1.hours, :public => true
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  def stores
    @title = 'Store Locator'
  end
  
  def update_map
    @stores = Store.active.physical_stores.where(:country => 'United States').map {|e| e}
    render :partial => "store", :collection => @stores
  end
  
private

  def process_feed(source)
    if @feed.new_record? || @feed.updated_at < 5.minutes.ago
      feed = Feedzirra::Feed.fetch_and_parse(source)
      feed.sanitize_entries!
      @feed.feeds = feed.entries.to_json
      @feed.save
    end
  end
  
  def get_search
    get_search_objects
    @breadcrumb_tags = @facets_hash.blank? ? [] : Tag.any_of(*@facets_hash.map {|e| {:tag_type => e.split("~")[0], :permalink => e.split("~")[1]}}).cache
    @sort_options = idea? ? [["Relevance", nil], ["New Ideas", "start_date_#{current_system}:desc"], ["Idea Name [A-Z]", "sort_name:asc"], ["Idea Name [Z-A]", "sort_name:desc"]] :
                      [["Relevance", nil], ["New Arrivals", "start_date_#{current_system}:desc"], ["Best Sellers", "quantity_sold:desc"], ["Lowest Price", "price_#{current_system}_#{current_currency}:asc"], ["Highest Price", "price_#{current_system}_#{current_currency}:desc"], ["Product Name [A-Z]", "sort_name:asc"], ["Product Name [Z-A]", "sort_name:desc"]]
    @product_search = perform_search(Product)
    @idea_search = perform_search(Idea)
    @outlet_search = perform_search(Product, :outlet => true) if is_sizzix_us?
    @search = if outlet?
      @outlet_search
    elsif idea?
      @idea_search
    else
      @product_search
    end
  end
  
  def get_search_objects
    @klass = idea? ? Idea : Product
    @secondary_klass = idea? ? Product : Idea
    @facets = params[:facets] || ""
    @facets_hash = @facets.split(",")
    @multi_facets_hash = {}
    @facets_hash.each {|e| @multi_facets_hash[e.split("~")[0]].blank? ? @multi_facets_hash[e.split("~")[0]] = e.split("~")[1] : @multi_facets_hash[e.split("~")[0]] << ",#{e.split("~")[1]}"}
  end
  
  # @Example: perform_search Product, :outlet => true, :facets => ["theme", "category"], :facet_sort => :index
  def perform_search(klass, options = {})
    outlet = options.delete(:outlet) ? true : false
    facets = options[:facets] || tag_types
    klass.search do |query|
      query.keywords params[:q] unless params[:q].blank?
      query.adjust_solr_params do |params|
        params[:"spellcheck"] = true
        params[:"spellcheck.collate"] = true
      end
      query.with :"listable_#{current_system}", true
      @filter_conditions = {}
      if MULTIFACETS
        @multi_facets_hash.each do |k,v|
          @filter_conditions[k] = query.with :"#{k}_#{current_system}", v.split(",").map {|e| "#{k}~#{e}"}
        end
      else
        @facets_hash.each do |f|
          query.with :"#{f.split("~")[0]}_#{current_system}", f
        end
      end
      facets.each do |e|
        query.facet :"#{e.to_s}_#{current_system}", :exclude => @filter_conditions[e], :sort => options[:facet_sort] || :count
      end
      unless klass == Idea
        query.with :outlet, outlet if is_sizzix_us?
        query.with(:"price_#{current_system}_#{current_currency}", params[:price].split("~")[0]..params[:price].split("~")[1]) unless params[:price].blank?
        query.with(:"saving_#{current_system}_#{current_currency}", params[:saving].split("~")[0]..params[:saving].split("~")[1]) unless params[:saving].blank?
        query.facet(:price) do |qf|
          PriceFacet.instance.facets(outlet).each do |price_range|
            qf.row(price_range) do
              with(:"price_#{current_system}_#{current_currency}", price_range.min..price_range.max)
            end
          end
        end
      end
      if outlet && klass != Idea
        query.facet(:saving) do |qf|
          PriceFacet.instance.savings.each do |saving|
            qf.row(saving) do
              with(:"saving_#{current_system}_#{current_currency}", saving.min..saving.max)
            end
          end
        end
      end
      query.paginate(:page => params[:page] || 1, :per_page => @per_page || per_page)
      query.order_by(*params[:sort].split(":")) unless params[:sort].blank?
    end
  end
  
  # solr filter display logic
  def tag_types
    @filter_names = @facets.split(",").map {|e| e[/^(\w+)/]}
    tags = Tag::TYPES.reject {|e| e =~ /^sub/ unless @filter_names.include?(e.gsub(/^sub/,''))} - Tag::HIDDEN_TYPES
    tags -= ["product_family"] unless @filter_names.include?("product_line")
    tags -= ["release_date", "special"] unless ecommerce_allowed?
    tags
  end
  
  def idea?
    params[:ideas] == "1"
  end
  
  def per_page
    case params[:per_page]
    when "48"
      48
    when "72"
      72
    when "96"
      96
    else
      24
    end
  end
end