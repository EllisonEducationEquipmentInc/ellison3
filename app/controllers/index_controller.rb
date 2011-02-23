class IndexController < ApplicationController
  
  include Geokit::Geocoders
	
  before_filter :trackable, :except => [:catalog]
  before_filter :store_path!
  
  ssl_required :contact, :send_feedback
  
  verify :xhr => true, :only => [:search, :quick_search, :send_feedback, :add_comment], :redirect_to => {:action => :home}
    
  helper_method :idea?, :per_page
  
  def home
    @home_content = SharedContent.home
  end
  
  def campaigns
    @campaign = SharedContent.campaigns
  end
  
  def products
    @products = Product.available.paginate :page => params[:page], :per_page => 24
  end
  
  def product
    @product = if params[:id].present?
      Product.send(current_system).find(params[:id])
    else
      Product.displayable.where(:item_num => params[:item_num]).first
    end
    raise "Invalid product" unless @product.displayable?
    @title = @product.name
    @keywords = @product.keywords if @product.keywords.present?
    @keywords << @product.tags.keywords.map {|e| e.name} * ', '
    @description = @product.description if @product.description.present?
    #redirect_to :action => "outlet", :anchor => "q=#{@product.item_num}" and return if !request.xhr? && is_sizzix_us? && @product && @product.outlet 
    if request.xhr?
      render :product_min, :layout => false and return 
    else
      #fresh_when(:etag => [current_locale, current_system, @product, current_user, request.xhr?], :last_modified => @product.updated_at.utc)
    end
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  def idea
    @idea = if params[:id].present?
      Idea.send(current_system).find(params[:id])
    else
      Idea.available.where(:idea_num => params[:idea_num]).first
    end
    raise "Invalid idea" unless @idea.listable?
    @title = @idea.name
    @keywords = @idea.keywords if @idea.keywords.present?
    @keywords << @idea.tags.keywords.map {|e| e.name} * ', '
    @description = @idea.description if @idea.description.present?
    #fresh_when(:etag => [current_system, @idea], :last_modified => @idea.updated_at.utc)
  rescue Exception => e
    Rails.logger.info e
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
    #fresh_when(:etag => [current_locale, current_system, @landing_page], :last_modified => @landing_page.updated_at.utc)
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
    #expires_in 1.hours, 'max-stale' => 1.hours
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
    process_feed("http://sizzixblog.blogspot.com/feeds/posts/default?alt=rss&max-results=5")
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
  
  def videos
    @title = "Videos"
    @feed = Feed.where(:name => "video_paylist_#{current_system}").first || Feed.new(:name => "video_paylist_#{current_system}")
    process_feed("http://gdata.youtube.com/feeds/api/users/#{youtube_user}/playlists", 60)
    client = YouTubeIt::Client.new
    @videos = Rails.cache.fetch("videos_#{current_system}", :expires_in => 60.minutes) do
      @feed.entries.inject([]) {|arr, e| arr << client.playlist(e["entry_id"][/\w+$/])}
    end
    @recent_uploads = Rails.cache.fetch("recent_uploads_#{current_system}", :expires_in => 60.minutes) do
      client.videos_by(:author => youtube_user, :order_by => 'published', :time => 'this_month').videos
    end
  end
  
  def search_videos
    client = YouTubeIt::Client.new
    @videos = client.videos_by(:author => youtube_user, :order_by => 'relevance', :query => params[:q]).videos
    if @videos.present?
      render :partial => 'video', :collection => @videos
    else
      render :text => "<li style='width: 900px;'>Sorry, there are no #{system_name.titleize} videos about <strong>#{params[:q]}</strong>.<br />Please try another search.</li>"
    end
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
    params[:country] ||= is_us? ? 'United States' : 'United Kingdom'
    params[:brands] ||= if is_sizzix? 
        'sizzix' 
      elsif is_ee?
        'ellison'
      else
        'sizzix,ellison'
      end
    @countries = Store.active.physical_stores.order_by(:country, :desc).distinct(:country).sort {|x,y| x <=> y}
    @online_stores = Store.active.webstores.order_by(:name, :asc).cache
    @distributors = Store.active.distributors.order_by(:name, :asc).cache
    @store_locator_content = SharedContent.store_locator
    @title = 'Store Locator'
  end
  
  def update_map
    criteria = Mongoid::Criteria.new(Store)
    criteria = criteria.where.physical_stores
    criteria = criteria.where(:brands.in => params[:brands]) if params[:brands].present?
    if params[:country] && params[:country] != 'United States'
      @stores = criteria.where(:country => params[:country]).map {|e| e}
    elsif params[:zip_code].present? && params[:zip_code] =~ /^\d{5,}/
      @zip_geo = MultiGeocoder.geocode(params[:zip_code])
      @stores = criteria.where(:location.within => { "$center" => [ [@zip_geo.lat, @zip_geo.lng], params[:radius].to_i] }).map {|e| e}
    end
    render :partial => "store", :collection => @stores
  end
  
  def events
    @events = Event.available.cache
    @title = "Events"
  end
  
  def event
    @event = Event.find(params[:id])
    @title = "Event - #{@event.name}"
  end
  
  def calendar
    @month = (params[:month] || Time.zone.now.month).to_i
    @year = (params[:year] || Time.zone.now.year).to_i

    @shown_month = Date.civil(@year, @month)

    @event_strips = Tag.event_strips_for_month(@shown_month)
  end
  
  def machines_survey
    cookies[:machines] = {:value => params[:machines].join(","), :expires => 30.days.from_now}
    current_user.update_attribute(:machines_owned, params[:machines]) if user_signed_in?
    render :js => "alert('Thank you.');$('#machines_owned').remove();"
  end
  
  def instructions
    @products = Product.available.where(:instructions.exists => true, :instructions.ne => '').asc(:name).cache
    #expires_in 3.hours, 'max-stale' => 5.hours
  end
  
  # old rails 2 url redirects:
  def old_product
    old_id_field = if is_ee?
      :old_id_edu
    elsif is_er?
      :old_id_er
    elsif is_sizzix_uk?
      :old_id_szuk
    else
      :old_id
    end
    @product = Product.displayable.where(old_id_field => params[:old_id]).first
    redirect_to product_path(:item_num => @product.item_num, :name => @product.name.parameterize), :status => 301
  rescue Exception => e
    go_404
  end
  
  def old_idea
    old_id_field = is_ee? ? :old_id_edu : :old_id
    @idea = Idea.available.where(old_id_field => params[:old_id]).first
    redirect_to idea_path(:idea_num => @idea.idea_num, :name => @idea.name.parameterize), :status => 301
  rescue Exception => e
    go_404
  end
  
  def old_catalog
    @tag = Tag.available.where(:name => params[:name], :tag_type => params[:tag_type]).first
    redirect_to catalog_path(:anchor => "facets=#{@tag.facet_param}"), :status => 301
  rescue Exception => e
    go_404
  end
  
private

  def process_feed(source, mins = 5)
    if @feed.new_record? || @feed.updated_at < mins.minutes.ago
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
    params[:sort] = "orderable_#{current_system}:desc" if params[:sort].blank?
    outlet = options.delete(:outlet) ? true : false
    facets = options[:facets] || tag_types
    klass.search do |query|
      query.keywords params[:q] unless params[:q].blank?
      query.adjust_solr_params do |params|
        # enable spellcheck:
        params[:"spellcheck"] = true
        params[:"spellcheck.collate"] = true
        # if keywords are item nums separated by spaces, keyword search minimum should match = 0. same as OR. see http://wiki.apache.org/solr/DisMaxQParserPlugin
        params[:mm] = 0 if params[:q].present? && params[:q].split(/\s+/).all? {|e| e =~ /^(A|38-)?\d{4,6}-?[A-Z0-9.]{0,8}$/}
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
      query.order_by(*params[:sort].split(":")) unless params[:sort].blank? || klass == Idea && ['quantity_sold', 'price', 'orderable'].any? {|e| params[:sort].include? e}
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