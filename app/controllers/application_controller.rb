# encoding: utf-8
class ApplicationController < ActionController::Base
	
	before_filter :get_system
	before_filter :set_retailer_discount_level
	before_filter :page_title
	before_filter :set_clickid
	before_filter :get_meta_tags
	before_filter :get_navigation
	
	include ShoppingCart
	include SslRequirement

  protect_from_forgery
	
  layout :get_layout

	helper_method :vat, :gross_price, :calculate_vat, :get_user, :countries, :states, :sort_column, :sort_direction, :ga_tracker_id, :has_write_permissions?, :has_read_permissions?, :admin_systems,
	              :quote_allowed?, :chekout_allowed?, :currency_correct?, :vat_exempt?, :outlet?, :machines_owned

private

  def machines_owned
    cookies[:machines].split(",") rescue []
  end

  def outlet?
    is_sizzix_us? && params[:controller] == "index" && (params[:action] == 'outlet' || params[:outlet] == "1")
  end

	def get_user
		current_user
	end
	
	def chekout_allowed?
	  !is_ee_uk? && !get_cart.pre_order?
	end
	
	def quote_allowed?
	  is_ee?
	end
	
	# TODO: CMS for this
	def vat
		Rails.cache.fetch 'vat', :expires_in => 1.hour.since do
		  SystemSetting.value_at("vat").to_f
		end
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
		if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym) && allowed_locales.include?(params[:locale])
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
		end
	end
	
	def get_layout
	  is_er? && params[:tp].present? ? 'application_corp' : 'application'
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
  	elsif is_ee?
			@description = "Ellison Education - Curriculum-Based Die-Cutting for the Classroom | Create memorable visuals and essential hands-on activities for all ages and stages of K-12 student education. Fun Free Lesson Plans. Online deals."
			@keywords = "Educational Die-Cutting for Preschools, Elementary, Jr High, High School, Shape-cutting, Printable Free Lesson Plans for Educators, Teacher Lesson Ideas, Promotions, Coupons, Teacher Tools, Classroom Décor, Classroom Decorating, Education Standards, Curriculum Development, Children, Homeschool, Early Childhood Education, Bulletin Boards, Learning, Fundraising, Resources, Visual Aids, Cut Outs, Teacher Supplies, Custom Dies"
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
		[["Armed Forces Americas", "AA"], ["Armed Forces Europe", "AE"], ["Armed Forces Pacific", "AP"], ["Alabama", "AL"], ["Alaska", "AK"], ["Arizona", "AZ"], ["Arkansas", "AR"], ["California", "CA"], ["Colorado", "CO"], ["Connecticut", "CT"], ["Delaware", "DE"], ["District of Columbia", "DC"], ["Florida", "FL"], ["Georgia", "GA"], ["Hawaii", "HI"], ["Idaho", "ID"], ["Illinois", "IL"], ["Indiana", "IN"], ["Iowa", "IA"], ["Kansas", "KS"], ["Kentucky", "KY"], ["Louisiana", "LA"], ["Maine", "ME"], ["Maryland", "MD"], ["Massachutsetts", "MA"], ["Michigan", "MI"], ["Minnesota", "MN"], ["Mississippi", "MS"], ["Missouri", "MO"], ["Montana", "MT"], ["Nebraska", "NE"], ["Nevada", "NV"], ["New Hampshire", "NH"], ["New Jersey", "NJ"], ["New Mexico", "NM"], ["New York", "NY"], ["North Carolina", "NC"], ["North Dakota", "ND"], ["Ohio", "OH"], ["Oklahoma", "OK"], ["Oregon", "OR"], ["Pennsylvania", "PA"], ["Rhode Island", "RI"], ["South Carolina", "SC"], ["South Dakota", "SD"], ["Tennessee", "TN"], ["Texas", "TX"], ["Utah", "UT"], ["Vermont", "VT"], ["Virginia", "VA"], ["Washington", "WA"], ["West Virginia", "WV"], ["Wisconsin", "WI"], ["Wyoming", "WY"]]
	end
	
  def sort_direction  
    %w[asc desc].include?(params[:direction]) ?  params[:direction] : "desc"  
  end

  def sort_column  
    params[:sort] || "updated_at"  
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
	  elsif request.subdomain.present? && request.subdomain == 'qa'
	    "UA-12678772-5"
	  else
	    if is_sizzix?
	      is_us? ? 'UA-3328816-1' : 'UA-3328816-6'
	    elsif is_ee?
	      is_us? ? 'UA-3328816-2' : 'UA-3328816-7'
	    else
	      'UA-3328816-8'
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
  
end
