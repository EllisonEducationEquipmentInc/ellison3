module EllisonSystem  
	
	# define which locale has what currency
	LOCALES_2_CURRENCIES = {'en-US' => 'usd', 'en-UK' => 'gbp', 'en-EU' => 'eur'}
	
	# define systems here
	ELLISON_SYSTEMS = %w(szus szuk eeus eeuk er)

	def current_system
		Thread.current[:current_system] ||= ELLISON_SYSTEMS.first
	end
	
	def current_system=(s)
		Thread.current[:current_system] = s if ELLISON_SYSTEMS.include?(s)
		set_default_locale
		current_system
	end
	
	def set_current_system(s)
		self.current_system = s
	end
	
	def current_locale
		I18n.locale
	end
	
	def current_locale=(l)
		I18n.locale = l if LOCALES_2_CURRENCIES.keys.include?(l.to_s)
	end
	
	def set_current_locale(l)
		self.current_locale = l
	end
  
	def current_currency
		LOCALES_2_CURRENCIES[current_locale.to_s]
	end
	
	def allowed_locales
		if %w(szuk eeuk).include? current_system
			["en-UK", "en-EU"]
		else
			["en-US"]
		end
	end
	
	def currencies
		LOCALES_2_CURRENCIES.values_at *allowed_locales
	end
	
	def is_gbp?
		current_currency == 'gbp'
	end
	
	def is_eur?
		current_currency == 'eur'
	end
	
  def is_er?
    # is ellison_retailers?
    current_system == 'er'
  end
  
  def is_ee?
    # is ellison_education?
    current_system == 'eeus' || current_system == 'eeuk'
  end
  
  def is_sizzix?
    current_system == "szus" || current_system == "szuk"
  end
  
  def is_us?
    current_locale.to_sym == :"en-US"
  end
  
  def is_uk?
    current_locale.to_sym == :"en-UK" || current_locale.to_sym == :"en-EU"
  end
    
  def is_sizzix_us?
    is_sizzix? && is_us?
  end
  
  def is_sizzix_uk?
    is_sizzix? && is_uk?
  end
  
  def is_ee_us?
    is_ee? && is_us?
  end
  
  def is_ee_uk?
    is_ee? && is_uk?
  end

	# if gross prices are displayed (if prices include tax/vat)
	def gross_prices?(currency = nil)
		currency ||= current_currency
		!%(usd).include?(currency)
	end
  
  def order_prefix
    current_system.upcase
  end
  
  def get_domain
    if is_er? 
      "ellison.com"
    elsif is_ee?
      "ellisoneducation.#{is_us? ? 'com' : 'co.uk'}"
    else
      "sizzix.#{is_us? ? 'com' : 'co.uk'}"
    end
  end

	# EY app names
	def app_name
		if is_sizzix_us?
      "sizzix_2_us"
		elsif is_sizzix_uk?
			"sizzix_2_uk"
    elsif is_ee_us?
      "ellison_education"
		elsif is_ee_uk?
			"ellison_education_uk"
    elsif is_er?
      "ellison_global"
    end
	end
	
	def system_name
		{"szus" => "Sizzix",  "szuk" => "Sizzix UK", "eeus" => "Ellison Education", "eeuk" => "Ellison Education UK", "er" => "Ellison Retailers"}[current_system]
	end
	
	def set_default_locale
		if %w(szus eeus er).include?(current_system) && current_locale.to_sym != :"en-US"
			set_current_locale "en-US"
		elsif %w(szuk eeuk).include?(current_system) && current_locale.to_sym == :"en-US"
			set_current_locale "en-UK"
		end
		[@current_system, @current_locale]
	end
	
	def domain_to_system(domain)
		case domain
		when /sizzix\.com$/
			set_current_system 'szus'
		when /sizzix\.co\.uk$/
			set_current_system 'szuk'
		when /ellisoneducation\.com$/
			set_current_system 'eeus'
		when /ellisoneducation\.co\.uk$/
			set_current_system 'eeuk'
		when /ellison\.com$/
			set_current_system 'er'
		else
			set_current_system 'szus'
		end
	end
	
end

class ActiveRecord::Base
  include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActionView::Base
  include EllisonSystem
end

class ActionMailer::Base
  include EllisonSystem
end

class ActionController::Base
  include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActiveRecord::Migration
	include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActionController::IntegrationTest
	include EllisonSystem
  class << self
    include EllisonSystem
  end
end
