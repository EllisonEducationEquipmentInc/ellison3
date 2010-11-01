class ApplicationController < ActionController::Base
	
	before_filter :get_system
	before_filter :page_title
	
	include ShoppingCart
	include SslRequirement

  protect_from_forgery
	
  layout :get_layout

	helper_method :vat, :gross_price, :calculate_vat, :get_user, :countries, :states, :sort_column, :sort_direction, :ga_tracker_id, :has_write_permissions?, :has_read_permissions?, :admin_systems,
	              :quote_allowed?, :chekout_allowed?

private

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
		@vat ||= SystemSetting.value_at("vat").to_f
	end
	
	# TODO: implement VAT exempt by SHipping Country
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

	def get_system
		domain_to_system(request.host)
		if Rails.env == 'development' || admin_signed_in?
			# TODO: restrict admin to switch to enabled systems only
			session[:system] = params[:system] if params[:system]
			set_current_system(session[:system])
		end
		set_locale
	end
	
	def set_locale
		I18n.locale = session[:locale] if session[:locale] && allowed_locales.include?(session[:locale].to_s)
		if params[:locale] && I18n.available_locales.include?(params[:locale].to_sym) && allowed_locales.include?(params[:locale])
			I18n.locale = params[:locale]
			get_cart.reset_tax_and_shipping
			get_cart.update_items
		end
		session[:locale] = I18n.locale
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
	
	def go_404
		render :file => "#{Rails.root}/public/404_#{current_system}.html", :layout => false, :status => 404
	end
	
	def countries
		# TODO: make it dynamic
		if is_us? && !is_er?
			["United States"]
		else
			Country.all.cache.map {|c| c.name}
		end
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
  rescue
    ''
  end
  
end
