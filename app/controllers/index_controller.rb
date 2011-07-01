class IndexController < ApplicationController
  
  include Geokit::Geocoders
  
  before_filter :trackable, :except => [:catalog]
  #before_filter :store_path!
  before_filter :register_continue_shopping!, :only => [:campaigns, :shop, :tag_group, :catalog]
  before_filter :register_last_action!, :only => [:product, :idea, :catalog]
  
  ssl_required :contact, :send_feedback, :reply_to_feedback
  ssl_allowed :limited_search, :machines_survey, :static_page, :add_comment, :newsletter, :create_subscription, :subscription, :update_subscription, :resend_subscription_confirmation
  
  verify :xhr => true, :only => [:search, :quick_search, :send_feedback, :add_comment], :redirect_to => {:action => :home}
  verify :method => :post, :only => [:update_subscription, :create_subscription, :resend_subscription_confirmation], :redirect_to => {:action => :home}
    
  helper_method :idea?, :per_page
  
  def home
    @home_content = SharedContent.home
  end
  
  def campaigns
    @campaign = SharedContent.campaigns
  end
  
  def products
    redirect_to(catalog_path) and return
  end
  
  def product
    @product = if params[:id].present?
      Product.send(current_system).find(params[:id])
    else
      Product.displayable.where(:item_num => params[:item_num].gsub("point", ".")).first
    end
    raise "Invalid product" unless @product.displayable?
    @title = @product.name
    unless fragment_exist? ['product', @product, @product.updated_at.utc.to_i, current_system, current_locale, @product.price, Product.retailer_discount_level, ecommerce_allowed?, request.xhr?]
      @keywords = @product.keywords if @product.keywords.present?
      @keywords << @product.tags.keywords.map {|e| e.name} * ', '
      @description = @product.description if @product.description.present?
    end
    #redirect_to :action => "outlet", :anchor => "q=#{@product.item_num}" and return if !request.xhr? && is_sizzix_us? && @product && @product.outlet 
    if request.xhr?
      render :product_min, :layout => false and return 
    else
      fresh_when(:etag => [Time.now.utc.strftime("%m%d%Y%H"), current_locale, current_system, @product,  @product.price, current_user, request.xhr?], :last_modified => @product.updated_at.utc)
      #expires_in 5.minutes, 'max-stale' => 5.minutes
    end
  rescue Exception => e
    Rails.logger.info e.message
    redirect_to(tag_group_path("categories"))
  end
  
  def idea
    @idea = if params[:id].present?
      Idea.send(current_system).find(params[:id])
    else
      Idea.available.where(:idea_num => params[:idea_num]).first
    end
    raise "Invalid idea" unless @idea.listable?
    @title = @idea.name
    unless fragment_exist? ['idea', @idea, @idea.updated_at.utc.to_i, current_system, current_locale, Product.retailer_discount_level, ecommerce_allowed?]
      @keywords = @idea.keywords if @idea.keywords.present?
      @keywords << @idea.tags.keywords.map {|e| e.name} * ', '
      @description = @idea.description if @idea.description.present?
    end
    fresh_when(:etag => [Time.now.utc.strftime("%m%d%Y%H"), 'idea', @idea, @idea.updated_at.utc.to_i, current_system, current_locale], :last_modified => @idea.updated_at.utc)
    #expires_in 5.minutes, 'max-stale' => 5.minutes
  rescue Exception => e
    Rails.logger.info e
    redirect_to(tag_group_path("themes", :ideas => 1))
  end
  
  # landing page
  def shop
    @landing_page = LandingPage.available.find params[:id]
    unless fragment_exist? ['landing_page', @landing_page, @landing_page.updated_at.utc.to_i, current_system, current_locale, Product.retailer_discount_level, ecommerce_allowed?]
      params.merge! @landing_page.to_params
      @title = @landing_page.name
      get_search
      @products = @search.results
    end
    fresh_when(:etag => [Time.now.utc.strftime("%m%d%Y%H"), current_locale, current_system, @landing_page], :last_modified => @landing_page.updated_at.utc)
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  # /lp/:id
  def tag_group
    if %w(product_lines artists themes designers categories curriculums).include? params[:id]
      unless fragment_exist? ['tag_group', current_system, params[:id], params[:ideas]]
        get_search_objects
        @search = perform_search(@klass, :facets => [params[:id].singularize], :facet_sort => :index)
      end
    else
      raise "invalid tag_type: #{params[:id]}"
    end
    expires_in 1.hour, 'max-stale' => 3.hours
  rescue Exception => e
    Rails.logger.info e.message
    go_404
  end
  
  def catalog
    @title = "Catalog"
    #expires_in 3.hours, 'max-stale' => 5.hours
    fresh_when :etag => [Time.now.utc.strftime("%m%d%Y%H"), current_locale, current_system, current_user, flash, Time.zone.now.strftime("%m%d%Y%H"), admin_signed_in?]
  end
  
  def outlet
    @title = "Outlet"
  end
  
  def search
    # search filter - redirect to product or idea page if q is item_num or itea_num
    if params[:q].present? && params[:q] =~ /^(a|A)*[0-9]{3,6}($|-[a-zA-Z0-9\.]{1,10}$)/
      @product = Product.displayable.where(:item_num => params[:q]).first
      render :js => "location.href='#{product_url(:item_num => @product.url_safe_item_num, :name => @product.name.parameterize)}'" and return if @product
      @idea = Idea.available.where(:idea_num => params[:q]).first
      render :js => "location.href='#{idea_url(:idea_num => @idea.idea_num, :name => @idea.name.parameterize)}'" and return if @idea
    end
    # search filter - redirect to destination if search_phrase found
    if params[:q].present? && params[:q].length > 2
      @search_phrase = SearchPhrase.available.where(:phrase => params[:q]).first
      render :js => "location.href='#{@search_phrase.destination}'" and return if @search_phrase
    end
    session[:continue_shopping] = session[:last_action] = catalog_path + "#" + request.env["QUERY_STRING"]
    if params[:q].present? || !fragment_exist?([params.to_params.gsub("%", ":"), current_system, current_locale, ecommerce_allowed?, Product.retailer_discount_level])
      get_search
      @products = @search.results
    end
    #fresh_when :etag => [request.request_uri, current_system, current_locale, ecommerce_allowed?, Product.retailer_discount_level, Time.zone.now.strftime("%m%d%Y%H"), admin_signed_in?]
    expires_in 5.minutes, 'max-stale' => 10.minutes unless is_er?
  end
  
  def quick_search
    @landing_page = LandingPage.find params[:id]
    new_facets = params[:facets].present? ? params[:facets].split(",") : []
    original_facets = @landing_page.to_params["facets"].present? ? @landing_page.to_params["facets"].split(",") : []
    params.merge! @landing_page.to_params
    params[:facets] = (new_facets | original_facets).join(",")
    get_search
    render :partial => 'quick_search'
  end
  
  def contact
    @feedback = Feedback.new
    @feedback.email = get_user.email if user_signed_in?
    @subjects = SharedContent.active.where(:systems_enabled.in => [current_system], :placement => 'contact').order([:display_order, :asc]).cache
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
    unless fragment_exist?([params.to_params.gsub("%", ":"), current_system, current_locale, ecommerce_allowed?, Product.retailer_discount_level])
      get_search_objects
      @per_page = params[:per_page] if params[:per_page].to_i > 0
      @search = perform_search(@klass, :outlet => outlet?)
      @items = @search.results
    end
    expires_in 5.minutes, 'max-stale' => 10.minutes
    render :layout => false
  end
  
  def twitter_feed
    @feed = Feed.where(:name => 'twitter').first || Feed.new(:name => 'twitter')
    process_feed("http://twitter.com/statuses/user_timeline/46690271.rss")
    expires_in 10.minutes, 'max-stale' => 15.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def blog_feed
    @feed = Feed.where(:name => 'blog').first || Feed.new(:name => 'blog')
    process_feed("http://sizzixblog.blogspot.com/feeds/posts/default?alt=rss&max-results=5")
    expires_in 10.minutes, 'max-stale' => 15.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end

  def twitter_feed_uk
    @feed = Feed.where(:name => 'twitter_uk').first || Feed.new(:name => 'twitter_uk')
    process_feed("http://twitter.com/statuses/user_timeline/45567009.rss")
    expires_in 10.minutes, 'max-stale' => 15.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def blog_feed_uk
    @feed = Feed.where(:name => 'blog_uk').first || Feed.new(:name => 'blog_uk')
    process_feed("http://sizzixukblog.blogspot.com/feeds/posts/default?alt=rss&max-results=5", 60)
    expires_in 10.minutes, 'max-stale' => 15.minutes, :public => true
    render :partial => 'index/feed', :collection => @feed.entries
  end
  
  def videos
    @title = "Videos"
    unless fragment_exist? "videos_page_#{current_system}"
      get_videos
      @recent_uploads = Rails.cache.fetch("recent_uploads_#{current_system}", :expires_in => 60.minutes) do
        @client.videos_by(:author => youtube_user, :order_by => 'published', :time => 'this_month', :per_page => 2).videos
      end
    end
  end
  
  def video_page
    get_videos
    @playlist = @videos.detect {|e| e.playlist_id == params[:playlist_id]}
    @playlist.page = params[:page].to_i
    render :partial => 'playlist', :object => @playlist
  end
  
  def search_videos
    client = YouTubeIt::Client.new
    @videos = client.videos_by(:author => youtube_user, :order_by => 'relevance', :query => params[:q], :page => params[:page] || 1, :per_page => 48).videos
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
    if params[:no_layout]
      render :static_page, :layout => false
    else
      expires_in 1.hours, 'max-stale' => 1.hours, :public => true
    end
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
    criteria = criteria.where.active.physical_stores
    criteria = criteria.where(:brands.in => params[:brands]) if params[:brands].present?
    if params[:country] && params[:country] != 'United States'
      @stores = criteria.where(:country => params[:country]).map {|e| e}
    elsif params[:zip_code].present? && params[:zip_code] =~ /^\d{5,}/
      @zip_geo = MultiGeocoder.geocode(params[:zip_code])
      @stores = criteria.where(:location.within => { "$center" => [ [@zip_geo.lat, @zip_geo.lng], ((params[:radius].to_i * 20)/(3963.192*0.3141592653))] }).map {|e| e}
    end
    if @stores.present?
      render :partial => "store", :collection => @stores      
    else
      render :text => "No results found"
    end
  end
  
  def events
    @events = Event.available.asc(:event_start_date).cache
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
    @title = "Lesson calendar"
    @calendar_content = SharedContent.calendar
  end
  
  def machines_survey
    cookies[:machines] = {:value => params[:machines].join(","), :expires => 30.days.from_now}
    current_user.update_attribute(:machines_owned, params[:machines]) if user_signed_in?
    render :js => "$('#machine_msg').show();setTimeout(function(){$('#machine_msg').fadeOut('slow', function () {$('#machine_msg').remove();});}, 4000);"
  end
  
  def instructions
    unless fragment_exist? "instructions_page_#{current_system}"
      #@products = Product.displayable.only(:item_type).where(:instructions.exists => true, :instructions.ne => '').asc(:name).group
      @products = Product.collection.group(:key => 'item_type', :cond => {:deleted_at=>{"$exists"=>false}, :active=>true, :systems_enabled=>{"$in"=>[current_system]}, :"start_date_#{current_system}"=>{"$lte"=> Time.now.utc}, :"end_date_#{current_system}"=>{"$gte"=> Time.now.utc}, :instructions => {'$exists' => true, '$ne' => ''}}, :reduce => "function(obj, prev) { prev.group.push(obj); }", :initial=>{:group=>[]} ).collect do |docs|
        docs["group"] = docs["group"].collect do |attrs|
          Mongoid::Factory.build(Product, attrs)
        end
        docs
      end
    end
    expires_in 3.hours, 'max-stale' => 5.hours
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
    redirect_to product_path(:item_num => @product.url_safe_item_num, :name => @product.name.parameterize), :status => 301
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
  
  # UK blog 
  def blog
    raise "invalid system" unless is_sizzix_uk?
    @page = params[:page].try(:to_i) || 1
    @per_page = 10
    start_index = (@page-1)*@per_page + 1
    @feed = Feed.where(:name => "blog_uk_#{start_index}").first || Feed.new(:name => "blog_uk_#{start_index}")
    process_feed("http://sizzixukblog.blogspot.com/feeds/posts/default?alt=rss&max-results=#{@per_page}&start-index=#{start_index}", 60)
  rescue Exception => e
    go_404
  end
  
  def newsletter
    get_list_and_segments
    @subscription = Subscription.new :list => @list[0]
    @subscription.email = if params[:email]
        params[:email]
      elsif user_signed_in?
        current_user.email
      end
  end
  
  def create_subscription
    get_list_and_segments
    @subscribed = Subscription.first(:conditions => {:email => params[:subscription][:email], :list => subscription_list, :confirmed => false})
    @subscription = Subscription.new params[:subscription]
    @subscription.email = params[:subscription][:email]
    @subscription.list = subscription_list
    @subscription.list_name = @list[1]
    if @subscribed.blank? && @subscription.save
      # TODO: make them delayed
      begin
        @lyris = Lyris.new :create_single_member, :email_address => @subscription.email, :list_name => @subscription.list, :full_name => @subscription.name
        @lyris = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'confirm'
        @lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s} #if @subscription.segments.present?
        UserMailer.subscription_confirmation(@subscription).deliver
      rescue Exception => e
        Rails.logger.info e
        @subscription.delete
        redirect_to({:action => "newsletter", :email => params[:email]}, :alert => "An error has occured. Please try again later, or contact customer support.") and return
      end
      redirect_to(user_signed_in? && @subscription.email == current_user.email ? myaccount_path(:tab => 'subscriptions') : root_path, :notice => "Your subscription request has been successfully sent. You will receive a confirmation email shortly. Please follow its instructions to confirm your subscription.")
    else
      render :newsletter
    end
  end
  
  def resend_subscription_confirmation
    @subscription = Subscription.first(:conditions => {:email => params[:email], :list => subscription_list, :confirmed => false})
    if @subscription && recaptcha_valid?
      UserMailer.subscription_confirmation(@subscription).deliver
      flash[:notice] = "Your subscription request has been successfully sent. You will receive a confirmation email shortly. Please follow its instructions to confirm your subscription."
      render :js => "window.location.href = '#{user_signed_in? && @subscription.email == current_user.email ? myaccount_path(:tab => 'subscriptions') : root_path}'" and return
    end
  end
  
  def subscription
    @subscription = Subscription.find(params[:id])
    unless @subscription.confirmed
      @lyris = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'normal'
      @subscription.update_attribute :confirmed, true
      if user_signed_in? && @subscription.email == current_user.email
        flash[:notice] = "Thank you for verifying your email address."
        redirect_to(myaccount_path(:tab => 'subscriptions')) and return
      else
        flash.now[:notice] = "Thank you for confirming your email address. Please use this link in the future to manage your subscription settings."        
      end
    end
    get_list_and_segments
  end
  
  def update_subscription
    @subscription = Subscription.find(params[:id])
    get_list_and_segments
    params[:subscription][:segments] ||= []
    @subscription.write_attributes(params[:subscription])
    if @subscription.unsubscribe
      @lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @segments.keys.map {|e| {:name => e, :value => 0}} if @segments.present?
      @lyris = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'unsub'
      if @lyris.success?
        @subscription.segments = []
        @subscription.destroy
        flash[:notice] = "You have been Unsubscribed from #{@subscription.list_name}."
        redirect_to(user_signed_in? && @subscription.email == current_user.email ? myaccount_path(:tab => 'subscriptions') : root_path)
      else
        flash[:alert] = "an error has occured. please try again."
        render :subscription
      end
    else
      @lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @segments.keys.map {|e| {:name => e, :value => @subscription.segments.include?(e.to_s) ? 1 : 0}} if @segments.present?
      @subscription.save
      flash[:notice] = "Your Newsletter Subscription settings have been updated."
      redirect_to(user_signed_in? && @subscription.email == current_user.email ? myaccount_path(:tab => 'subscriptions') : {:action => "subscription", :id => @subscription.id})
    end
  end
  
  def error
    nil/3
  end
  
private

  def get_videos
    @feed = Feed.where(:name => "video_paylist_#{current_system}").first || Feed.new(:name => "video_paylist_#{current_system}")
    process_feed("http://gdata.youtube.com/feeds/api/users/#{youtube_user}/playlists", 60)
    @client = YouTubeIt::Client.new
    @videos = Rails.cache.fetch("videos_#{current_system}", :expires_in => 60.minutes) do
      @feed.entries.inject([]) do |arr, e|
        begin
          v = @client.playlist(e["entry_id"][/\w+$/])
          v.max_result_count = 24
          arr << v
        rescue Exception => e
          next
        end        
      end
    end
  end

  def process_feed(source, mins = 15)
    if @feed.new_record? || @feed.updated_at < mins.minutes.ago
      feed = Feedzirra::Feed.fetch_and_parse(source)
      feed.sanitize_entries!
      @feed.total_results = feed.total_results.to_i if feed.total_results.present?
      @feed.feeds = feed.entries.to_json
      @feed.save
    end
  end
  
  def get_search
    get_search_objects
    @breadcrumb_tags = @facets_hash.blank? ? [] : Tag.any_of(*@facets_hash.map {|e| {:tag_type => e.split("~")[0], :permalink => e.split("~")[1]}}).cache
    @sort_options = idea? ? [["Relevance", nil], ["New #{Idea.public_name.pluralize}", "start_date_#{current_system}:desc"], ["#{Idea.public_name} Name [A-Z]", "sort_name:asc"], ["#{Idea.public_name} Name [Z-A]", "sort_name:desc"]] :
                      [["Relevance", nil], ["New Arrivals", outlet? ? "outlet_since:desc" : "start_date_#{current_system}:desc"], ["Best Sellers", "quantity_sold:desc"], ["Lowest Price", "price_#{current_system}_#{current_currency}:asc"], ["Highest Price", "price_#{current_system}_#{current_currency}:desc"], ["Product Name [A-Z]", "sort_name:asc"], ["Product Name [Z-A]", "sort_name:desc"]]
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
    
end