class ApplicationController < ActionController::Base
  protect_from_forgery
	
	before_filter :get_system
	before_filter :page_title
	
	include ShoppingCart
	
  layout :get_layout

	helper_method :vat, :gross_price, :calculate_vat, :get_user, :countries, :states, :sort_column, :sort_direction, :ga_tracker_id

private

	# TODO: implement user_as
	def get_user
		current_user
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
			["United States", "Afghanistan", "Albania", "Algeria", "Andorra", "Angola", "Antarctica", "Antigua and Barbuda", "Argentina", "Armenia", "Australia", "Austria", "Azerbaijan", "Bahamas", "Bahrain", "Bangladesh", "Barbados", "Belarus", "Belgium", "Belize", "Benin", "Bermuda", "Bhutan", "Bolivia", "Bosnia and Herzegovina", "Botswana", "Brazil", "Brunei", "Bulgaria", "Burkina Faso", "Burundi", "Cambodia", "Cameroon", "Canada", "Cape Verde", "Central African Republic", "Chad", "Chile", "China", "Colombia", "Comoros", "Congo, Republic of the", "Costa Rica", "Cote d'Ivoire", "Croatia", "Cuba", "Cyprus", "Czech Republic", "Denmark", "Djibouti", "Dominica", "Dominican Republic", "Ecuador", "Egypt", "El Salvador", "Equatorial Guinea", "Eritrea", "Estonia", "Ethiopia", "Fiji", "Finland", "France", "Gabon", "Gambia", "Georgia", "Germany", "Ghana", "Greece", "Greenland", "Grenada", "Guatemala", "Guinea", "Guinea-Bissau", "Guyana", "Haiti", "Honduras", "Hong Kong", "Hungary", "Iceland", "India", "Indonesia", "Iran", "Iraq", "Ireland", "Israel", "Italy", "Jamaica", "Japan", "Jersey", "Jordan", "Kazakhstan", "Kenya", "Kiribati", "Korea, North", "Korea, South", "Kuwait", "Kyrgyzstan", "Laos", "Latvia", "Lebanon", "Lesotho", "Liberia", "Libya", "Liechtenstein", "Lithuania", "Luxembourg", "Macedonia", "Madagascar", "Malawi", "Malaysia", "Maldives", "Mali", "Malta", "Marshall Islands", "Mauritania", "Mauritius", "Mexico", "Micronesia", "Moldova", "Monaco", "Mongolia", "Morocco", "Mozambique", "Namibia", "Nauru", "Nepal", "Netherlands", "New Zealand", "Nicaragua", "Niger", "Nigeria", "Norway", "Oman", "Pakistan", "Panama", "Papua New Guinea", "Paraguay", "Peru", "Philippines", "Poland", "Portugal", "Puerto Rico", "Qatar", "Romania", "Russia", "Rwanda", "Samoa", "San Marino", "Sao Tome", "Saudi Arabia", "Senegal", "Serbia and Montenegro", "Seychelles", "Sierra Leone", "Singapore", "Slovakia", "Slovenia", "Solomon Islands", "Somalia", "South Africa", "Spain", "Sri Lanka", "Sudan", "Suriname", "Swaziland", "Sweden", "Switzerland", "Syria", "Taiwan", "Tajikistan", "Tanzania", "Thailand", "Togo", "Tonga", "Trinidad and Tobago", "Tunisia", "Turkey", "Turkmenistan", "Uganda", "Ukraine", "United Arab Emirates", "United Kingdom", "Uruguay", "Uzbekistan", "Vanuatu", "Venezuela", "Vietnam", "Yemen", "Zambia", "Zimbabwe"]
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
  
  
  # Google Analytics tracking methods
	def ga_tracker_id
	  "UA-12678772-3"
	end
  
  def track_page
    var pageTracker = _gat._getTracker('#{ga_tracker_id}');
    pageTracker._trackPageview();
  end
  
  def trackable
    @trackable = true
  end
end
