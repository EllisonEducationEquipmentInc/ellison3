# encoding: utf-8
class ApplicationController < ActionController::Base
	
	before_filter :fix_session
	before_filter :get_system
	before_filter :set_retailer_discount_level
	before_filter :page_title
	before_filter :set_clickid
	before_filter :get_meta_tags
	before_filter :get_navigation
	
	include ShoppingCart
	include SslRequirement
  include Rack::Recaptcha::Helpers

  protect_from_forgery
		
  layout :get_layout

	helper_method :vat, :gross_price, :calculate_vat, :get_user, :countries, :states, :provinces, :sort_column, :sort_direction, :ga_tracker_id, :has_write_permissions?, :has_read_permissions?, :admin_systems,
	              :quote_allowed?, :chekout_allowed?, :currency_correct?, :vat_exempt?, :outlet?, :machines_owned, :perform_search, :admin_user_as_permissions!, :convert_2_gbp, :is_admin?, :free_shipping_message

private

  def fix_session
    session.destroy if cookies[:_ellison3_session].present? && cookies[:_ellison3_session].valid_bson_object_id?
  end
  
  def after_sign_out_path_for(resource_or_scope)
    url_for(:controller => "index", :action => "home")
  end

  def machines_owned
    cookies[:machines].split(",") rescue []
  end

  def outlet?
    is_sizzix_us? && params[:controller] == "index" && (params[:action] == 'outlet' || params[:outlet] == "1")
  end
  
  def is_admin?
    params[:controller].start_with? "admin/"
  end

	def get_user
		current_user
	end
	
	def chekout_allowed?
	  !is_ee_uk? && !get_cart.pre_order? && get_cart.cart_items.none?(&:out_of_stock)
	end
	
	def quote_allowed?
	  is_ee?
	end
	
	def vat
		Rails.cache.fetch 'vat', :expires_in => 1.hour.since do
		  SystemSetting.value_at("vat").to_f
		end
	end
	
	def free_shipping_message
	  Rails.cache.fetch "free_shipping_message_#{current_system}", :expires_in => 1.hour.since do
		  SystemSetting.value_at "free_shipping_message_#{current_system}"
		end
	end
	
	def set_eur_gbp_rate
	  @rate = SystemSetting.find_by_key('eur_gbp_rate') || SystemSetting.new(:key => "eur_gbp_rate")
	  if @rate.new_record? || @rate.updated_at < Time.now.utc.beginning_of_day
	    # get actual rate from google
	    res = Net::HTTP.get_response(URI.parse('http://www.google.com/ig/calculator?hl=en&q=1EUR=?GBP'))
	    if rate = res.body[/(\d|\.){3,11}/]
	      @rate.value = rate
	      @rate.save
	      rate.to_f
	    end
	  else
	    @rate.value.to_f
	  end
  # rescue
  #   @rate.value.try(:to_f) || 0.873555404
	end
	
	def convert_2_gbp(amt)
    return amt unless is_eur?
    rate = Rails.cache.fetch 'eur_gbp_rate', :expires_in => 24.hour.since do
		  set_eur_gbp_rate
		end
    (rate * amt).round(2)
  end
	
	def gross_price(price, vat_exempt = false)
    sess = session[:vat_exempt] rescue vat_exempt
    if is_us? || sess || vat_exempt
      price
    else
      (price.to_f * (1+vat/100.0)).round(2)
    end
  end
  
  def calculate_vat(price, vat_exempt = false)
    sess = session[:vat_exempt] rescue vat_exempt
    if is_us? || sess || vat_exempt
      0.0
    else
      (price.to_f * (vat/100.0)).round(2)
    end
  end
  
  def set_vat_exempt
    session[:vat_exempt] = vat_exempt? if is_uk?
  end
  
  def vat_exempt?
    user_signed_in? && get_user.shipping_address && get_user.shipping_address.vat_exempt?
  end
  
  def gbp_only?
    user_signed_in? && get_user.billing_address && get_user.billing_address.gbp_only?
  end
  
  def currency_correct?
    !is_uk? || is_uk? && (gbp_only? && is_gbp? || !gbp_only? && is_eur?)
  end
  
  def set_proper_currency!
    if is_uk? && user_signed_in? && get_user.billing_address && !currency_correct? 
      session[:locale] = I18n.locale = gbp_only? ? 'en-UK' : 'en-EU'
      get_cart.reset_tax_and_shipping
			get_cart.update_items
    end
  end

	def get_system
	  session[:vat_exempt] = nil
	  domain_to_system(request.host)
	  if Rails.env == 'development' || admin_signed_in?
	    if session[:system].blank?
	      session[:system] = current_system
	    else
	      set_current_system session[:system]
	    end
      change_current_system(params[:system]) if params[:system]
	  end
		set_locale
	end
	
	def set_locale
		I18n.locale = session[:locale] if session[:locale] && allowed_locales.include?(session[:locale].to_s)
		set_default_locale unless allowed_locales.include?(I18n.locale.to_s)
		if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym) && allowed_locales.include?(params[:locale]) && I18n.locale.to_s != params[:locale]
			I18n.locale = params[:locale]
			get_cart.reset_tax_and_shipping
			get_cart.update_items
		end
		session[:locale] = I18n.locale
	end
	
	def change_current_system(new_system)
	  if Rails.env == 'development' || admin_signed_in?
			# TODO: restrict admin to switch to enabled systems only
			session[:locale] = nil
			session[:system] = new_system
			set_current_system(new_system)
			sign_out(current_user) if user_signed_in? && !current_user.systems_enabled.include?(current_system)
		end
	end
	
	def get_layout
	  'application'
	end
	
	# define default meta title here. overrite @title at the action level. 
	def page_title
		@title = if is_sizzix?
			"The Start of Something You."
		elsif is_ee?
			"Curriculum-based shape-cutting for the classroom"
		elsif is_er?
			"Leading Expression"
		else	
			"Dies, Die Cutting Machines & Scrapbooking Tools"
		end
	end
	
	def get_meta_tags
  	if is_sizzix_uk?
  		@keywords = "arts and crafts, art and craft, card making, cardmaking, card making instructions, make greetings cards, make cards, scrapbooking, rubber stamps, paper crafts, papercraft, home décor, quilting, appliqué, wedding stationery, embellishments, embellish, Fiona Williams, Pete Hughes, QVC, Hobbycraft, eclips, eclipse, Cuttlebug, cricut, die cutting, cutting die, shape cutter, shape cutting, scrapbooking, scrap booking, scrap book, scrapbook, embossing, tim holtz, alterations, rub ons, design, ideas, craft, crafting, card cutting, inspiration, texture boutique, top tips, hobby, christmas, halloween, xmas, card cutting, sizzix, ellison, big shot, hello kitty, embossing, present box, gift boxes, bigz xl, cutting pad, sizzlits, bags & boxes, cutting dies, bigz dies, textures, emboslits, clearlits, little sizzles, texturz, texture plates, alphabet sets, discount craft, embossing folders, cutting mat, XL cutting plates, shape-cutting, die cut, shape cut, cut out shapes, quilting, fabric, felt, paper, cardstock, chip board, mount board, texture, textured paper, jelly rolls, patch work squares, card designs, card ideas"
	    @description = "There's no bigger or better place for craft materials, equipment and inspiration. Sizzix.co.uk has 1000's of different ideas and craft activities from exclusive Sizzix designers. Get creative with Sizzix, make light work of crafting and turn your hobby into a passion. Sizzix products are so versatile - your not restricted to paper, you can cut anything from paper and cardstock to fabric and chip board. In fact any bigz die with the steel rule blade technology will cut paper, fabric, card, felt, chip board and much, much more. You are never on your own with Sizzix we have a huge section of inspirational project ideas using a huge selection of die and embossing technologies. Creative ideas are always being added using all the die and embossing technologies. The eclips electronic shape cutter is perfect for all your crafting projects whether you love scrapbooking, cardmaking or home decor"
  	elsif is_ee_us?
			@description = "Ellison Education - Curriculum-Based Die-Cutting for the Classroom | Create memorable visuals and essential hands-on activities for all ages and stages of K-12 student education. Fun Free Lesson Plans. Online deals."
			@keywords = "Educational Die-Cutting for Preschools, Elementary, Jr High, High School, Shape-cutting, Printable Free Lesson Plans for Educators, Teacher Lesson Ideas, Promotions, Coupons, Teacher Tools, Classroom Décor, Classroom Decorating, Education Standards, Curriculum Development, Children, Homeschool, Early Childhood Education, Bulletin Boards, Learning, Fundraising, Resources, Visual Aids, Cut Outs, Teacher Supplies, Custom Dies, Die Cuts, Die Cut Machine, eclips"	    
    elsif is_ee_uk?
			@description = "Ellison Education - Curriculum-Based Die-Cutting for the Classroom | Create memorable visuals and essential hands-on activities for all ages and stages of K-12 student education. Fun Free Lesson Plans. Online deals."
			@keywords = "Educational Die-Cutting for Preschools, Elementary, Jr High, High School, Shape-cutting, Printable Free Lesson Plans for Educators, Teacher Lesson Ideas, Promotions, Coupons, Teacher Tools, Classroom Décor, Classroom Decorating, Education Standards, Curriculum Development, Children, Homeschool, Early Childhood Education, Bulletin Boards, Learning, Fundraising, Resources, Visual Aids, Cut Outs, Teacher Supplies, Custom Dies, Die Cuts, Die Cut Machine"
		else
		  @keywords = ''
		  @description = ''
		end
  end
	
	def go_404
		render :file => "#{Rails.root}/public/404_#{current_system}.html", :layout => false, :status => 404
	end
	
	def countries
	  Country.send(current_system).cache.order_by(:display_order.asc, :name.asc).map {|e| e.name}
	end

	def states
		[["Armed Forces Americas", "AA"], ["Armed Forces Europe", "AE"], ["Armed Forces Pacific", "AP"], ["Alabama", "AL"], ["Alaska", "AK"], ["Arizona", "AZ"], ["Arkansas", "AR"], ["California", "CA"], ["Colorado", "CO"], ["Connecticut", "CT"], ["Delaware", "DE"], ["District of Columbia", "DC"], ["Florida", "FL"], ["Georgia", "GA"], ["Hawaii", "HI"], ["Idaho", "ID"], ["Illinois", "IL"], ["Indiana", "IN"], ["Iowa", "IA"], ["Kansas", "KS"], ["Kentucky", "KY"], ["Louisiana", "LA"], ["Maine", "ME"], ["Maryland", "MD"], ["Massachusetts", "MA"], ["Michigan", "MI"], ["Minnesota", "MN"], ["Mississippi", "MS"], ["Missouri", "MO"], ["Montana", "MT"], ["Nebraska", "NE"], ["Nevada", "NV"], ["New Hampshire", "NH"], ["New Jersey", "NJ"], ["New Mexico", "NM"], ["New York", "NY"], ["North Carolina", "NC"], ["North Dakota", "ND"], ["Ohio", "OH"], ["Oklahoma", "OK"], ["Oregon", "OR"], ["Pennsylvania", "PA"], ["Rhode Island", "RI"], ["South Carolina", "SC"], ["South Dakota", "SD"], ["Tennessee", "TN"], ["Texas", "TX"], ["Utah", "UT"], ["Vermont", "VT"], ["Virginia", "VA"], ["Washington", "WA"], ["West Virginia", "WV"], ["Wisconsin", "WI"], ["Wyoming", "WY"]]
	end
	
	def provinces
	  [["Alberta", "AB"], ["British Columbia", "BC"], ["Manitoba", "MB"], ["New Brunswick", "NB"], ["Newfoundland & labrador", "NL"], ["Northwest Territories", "NT"], ["Nova Scotia", "NS"], ["Nunavut", "NU"], ["Ontario", "ON"], ["Prince Edward Island", "PE"], ["Quebec", "QC"], ["Saskatchewan", "SK"], ["Yukon", "YK"]]
	end
	
  def sort_direction  
    %w[asc desc].include?(params[:direction]) ?  params[:direction] : "desc"  
  end

  def sort_column  
    params[:order] || "updated_at"  
  end
  
  def help
    Helper.instance
  end
  
  # include NumberHelper 
  class Helper
    include Singleton
    include ActionView::Helpers::NumberHelper
  end
  
  def no_cache
    response.headers["Last-Modified"] = Time.now.httpdate
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"
    response.headers["Pragma"] = "no-cache"
    response.headers["Cache-Control"] = 'no-store, private, must-revalidate, proxy-revalidate, max-age=0, pre-check=0, post-check=0, no-cache, private'
    response.headers['Vary'] = '*'
  end
  
  # Google Analytics tracking methods
	def ga_tracker_id
	  if Rails.env == "development"
	    "UA-12678772-3"
	  elsif Rails.env == "staging" #request.subdomain.present? && request.subdomain == 'qa'
	    "UA-12678772-5"
	  else
	    if is_sizzix?
	      is_us? ? 'UA-3328816-1' : 'UA-23939177-1'
	    elsif is_ee?
	      is_us? ? 'UA-3328816-2' : 'UA-23939177-5'
	    else
	      params[:tp] == 'g' || params[:tp] == 'c' ? 'UA-3328816-9' : 'UA-3328816-8'
	    end
	  end
	end
  
  def track_page
    var pageTracker = _gat._getTracker('#{ga_tracker_id}');
    pageTracker._trackPageview();
  end
  
  def trackable
    @trackable = true
  end
  
  def admin_read_permissions!
    authenticate_admin!
    redirect_to admin_path, :alert => "You have no permissions to access this module." and return unless current_admin.has_read_access?(self.controller_name)
  end
  
  def admin_write_permissions!
    redirect_to admin_path, :alert => "You have no permissions to perform this action." and return unless has_write_permissions?
  end
  
  def admin_user_as_permissions!
    if request.xhr?
      render :js => "alert('You have no permissions to log in as customer or your session timed out.');window.location.href = '#{stored_location_for(:admin) || new_admin_session_path}';" and return unless admin_signed_in? && current_admin.can_act_as_customer
    else  
      authenticate_admin!
      redirect_to admin_path, :alert => "You have no permissions to log in as customer" and return unless current_admin.can_act_as_customer
    end
  end
  
  def has_write_permissions?(sys = current_system)
    current_admin.has_write_access?(self.controller_name, sys)
  end
  
  def has_read_permissions?(sys = current_system)
    current_admin.has_read_access?(self.controller_name, sys)
  end
  
  def admin_systems
    ELLISON_SYSTEMS.select {|s| has_read_permissions?(s)} & current_admin.systems_enabled
  end
  
  def generate_code(num_length = 4, alpha_length = 6)
    letters = ("A".."Z").to_a 
    numbers = ("0".."9").to_a
    code = ""
    1.upto(num_length) { |i| code << letters[rand(letters.size-1)] }
    1.upto(6) { |alpha_length| code << numbers[rand(numbers.size-1)] }
    code
  end
  
  def set_admin_title
    @title = "#{params[:controller].try(:humanize)} - #{params[:action].try(:humanize)} #{params[:id]}"
  end
  
  def store_path!
    session[:user_return_to] = request.fullpath if request.get? && !request.xhr?
  end
  
  def register_continue_shopping!
    session[:continue_shopping] = request.fullpath if request.get? && !request.xhr?
  end
  
  def register_last_action!
    session[:last_action] = request.fullpath if request.get? && !request.xhr?
  end
  
  def set_retailer_discount_level
    Product.retailer_discount_level = is_er? && user_signed_in? && get_user.status == 'active' && get_user.discount_level ? get_user.discount_level : nil
  end
  
  def set_clickid
		cookies[:clickid] = {:value => params[:clickid], :expires => 30.days.from_now} unless params[:clickid].blank?
		source = params[:utm_source] || "ORGANIC"
		cookies[:utm_source] = source if params[:utm_source]
		referrer = request.referer[/http(s)?:\/\/[a-z0-9.]+./] rescue ''
		other_utm = "&utm_campaign=#{params[:utm_campaign]}&utm_medium=#{params[:utm_medium]}" if params[:utm_campaign] || params[:utm_medium]
		if cookies[:tracking].blank?
			cookies[:tracking] = {:value => "date=#{Time.zone.now}&utm_source=#{source}#{other_utm}&clickid=#{cookies[:clickid]}&referrer=#{referrer}", :expires => 10.years.from_now} 
			tracking_logger.info cookies[:tracking]
		elsif params[:utm_source]
			cookies[:tracking] += ";date=#{Time.zone.now}&utm_source=#{source}#{other_utm}&clickid=#{cookies[:clickid]}&referrer=#{referrer}"
			tracking_logger.info cookies[:tracking]
		end
	end
	
	def get_navigation
	  @multi_facets_hash ||= {}
	  @top_navigations = TopNavigation.instance.list
	end
	
  # solr search methods:
  #
  # @Example: perform_search Product, :outlet => true, :facets => ["theme", "category"], :facet_sort => :index
  def perform_search(klass, options = {})
    outlet = options.delete(:outlet) ? true : false
    facets = options[:facets] || tag_types
    @per_page = options[:per_page]
    klass.search do |query|
      query.keywords params[:q] unless params[:q].blank? || options[:ignore_keyword]
      query.adjust_solr_params do |parameters|
        # enable spellcheck:
        parameters[:"spellcheck"] = true
        parameters[:"spellcheck.collate"] = true
        # if keywords are item nums separated by spaces, keyword search minimum should match = 0. same as OR. see http://wiki.apache.org/solr/DisMaxQParserPlugin
        parameters[:mm] = 0 if params[:q].present? && params[:q].split(/\s+/).all? {|e| e =~ /^(A|38-)?\d{4,6}-?[A-Z0-9.]{0,8}$/i}
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
      if is_er?
        item_group_query = query.with(:item_group, params[:brand].split(",")) unless params[:brand].blank?
        query.facet(:item_group, :exclude => item_group_query)
      end
      facets.each do |e|
        query.facet :"#{e.to_s}_#{current_system}", :exclude => @filter_conditions[e], :sort => options[:facet_sort] || :index, :limit => options[:facet_limit]
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
      query.order_by(*default_sort(klass).split(":")) unless default_sort(klass).blank? || klass == Idea && ['quantity_sold', 'price', 'orderable', 'outlet_since'].any? {|e| default_sort(klass).include? e}
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
  
  def default_sort(klass)
    return params[:sort] if params[:sort].present? || params[:q].present?
    klass == Idea ? "start_date_#{current_system}:desc" : "orderable_#{current_system}:desc"
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
