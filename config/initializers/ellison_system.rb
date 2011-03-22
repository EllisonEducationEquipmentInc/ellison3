module EllisonSystem  
	
	# define which locale has what currency
	LOCALES_2_CURRENCIES = {'en-US' => 'usd', 'en-UK' => 'gbp', 'en-EU' => 'eur'} unless const_defined?(:LOCALES_2_CURRENCIES)
	
	# define systems here
	ELLISON_SYSTEMS = %w(szus szuk eeus eeuk erus) unless const_defined?(:ELLISON_SYSTEMS)
	
	WAREHOUSES = %w(us uk sz)
	
	MACHINES = {"A10000" => "AllStar", "A10800" => "AllStar SuperStar", "655210" => "BIGkick", "655268" => "Big Shot", "655750" => "Big Shot Express", "656250" => "Big Shot Pro", "15569" => "LetterMachine Original", "15575" => "LetterMachine XL", "19101" => "Prestige Pro", "19528" => "Prestige Select", "19528" => "Prestige SpaceSaver", "26868" => "RollModel", "655397" => "Sidekick", "656225" => "Texture Boutique", "656850" => "Vagabond", "655934" => "eclips"}
	
	MULTIFACETS = true #false

  MAX_CART_VALUE = 100000
  MAX_ITEMS = 99
  MAX_PER_ITEM = 20
  MIN_ORDER = 0.01
  ER_MIN_ORDER = 100
  ER_FIRST_MIN_ORDER = 300
  
	def current_system
		Thread.current[:current_system] ||= ELLISON_SYSTEMS.first
	end
	
	def current_system=(s)
		Thread.current[:current_system] = s if ELLISON_SYSTEMS.include?(s)
		set_default_locale
		change_timezone
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
	
	def change_timezone
	  Time.zone = is_us? ? 'Pacific Time (US & Canada)' : 'London'
	end
	
	def allowed_locales(sys = current_system)
		if %w(szuk eeuk).include? sys
			["en-UK", "en-EU"]
		else
			["en-US"]
		end
	end
	
	def currencies(sys = current_system)
		LOCALES_2_CURRENCIES.values_at *allowed_locales(sys)
	end
	
	def is_gbp?
		current_currency == 'gbp'
	end
	
	def is_eur?
		current_currency == 'eur'
	end
	
  def is_er?
    # is ellison_retailers?
    current_system == 'erus'
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
  
  def order_prefix(sys = current_system)
    sys.upcase
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
  
  def consumersupport_email
    "consumersupport@#{get_domain}"
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
		{"szus" => "Sizzix",  "szuk" => "Sizzix UK", "eeus" => "Ellison Education", "eeuk" => "Ellison Education UK", "erus" => "Ellison Retailers"}[current_system]
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
		when /ellison\.com$/ || /ellisonretailers\.com$/
			set_current_system 'erus'
		else
			set_current_system 'szus'
		end
	end
	
	def quote_name
	  is_er? ? "Pre-order" : "Quote"
	end
	
	def youtube_user
	  is_sizzix? ? 'sizzix' : 'sizzix'
	end
	
	def tracking_logger
  	@tracking_logger ||= ActiveSupport::BufferedLogger.new("#{Rails.root}/log/tracking.log")
  end
  
  # COD accounts
  COD = Struct.new(:id, :label) 
  
  def cod_list
    [    
      COD.new('ABF', 'ABF'),
      COD.new('DH', 'DHL Ww Express'),
      COD.new('FDX2D', 'FedEx 2Day'),
      COD.new('FDXES', 'FedEx Express Saver'),
      COD.new('FDXIE', 'FedEx International Economy'),
      COD.new('FDXIP', 'FedEx International Priority'),
      COD.new('FDXPO', 'FedEx Priority Overnight'),
      COD.new('FDXSO', 'FedEx Standard Overnight'),
      COD.new('FXGround', 'FedEx Ground'),
      COD.new('SAIA', 'SAIA'),
      COD.new('SBA', 'SBS Air'),
      COD.new('SBO', 'SBS Ocean'),
      COD.new('UPS', 'UPS'),
      COD.new('YF', 'Yellow Freight')
    ]
  end

	
end

# class ActiveRecord::Base
#   include EllisonSystem
#   class << self
#     include EllisonSystem
#   end
# end

# class ActiveRecord::Migration
#   include EllisonSystem
#   class << self
#     include EllisonSystem
#   end
# end

class ActionView::Base
  include EllisonSystem
  class << self
    include EllisonSystem
  end
end

class ActionMailer::Base
  include EllisonSystem
  default :from => Proc.new {consumersupport_email}, :host => Proc.new {get_domain}
  layout 'user_mailer'
  
  class << self
    include EllisonSystem    
  end
end

class ActionController::Base
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

class Hash
  # Destructively convert all keys to integers.
  def integerify_keys!
    keys.each do |key|
      self[key.to_i] = delete(key)
    end
    self
  end
  
  # Destructively convert all values to floats.
  def floatify_values!
    each do |key, value|
      self[key] = value[/[0-9.]+/].to_f if value.is_a?(String)
    end
    self
  end
end
