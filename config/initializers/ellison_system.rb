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
  
  def backorder_allowed?(sys = current_system)
    sys == 'erus' || sys == 'eruk' || sys == 'eeus' || sys == 'eeuk'
  end
  
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
    current_system == 'erus' || current_system == 'eruk'
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
		when /ellison\.com$/, /ellisonretailers\.com$/
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
  
  def subscription_list
    case current_system
    when "szus"
      "sizzixscoop"
    when "szuk"
      "sizzix_uk_consumers"
    when "eeus"
      "connection"
    when "eeuk"
      "ellison_education_uk"
    when "erus"
      "erus_retailers"
    end
  end
  
  # the first element in the hash is the actual list name ex: :sizzix_scoop =>	"Sizzix Scoop" listname: sizzix_scoop
  # the other keys represent a column of the members table in lyris, values are the labels displayed on the front-end.
  # naming convention on lyris: in order to make it work, always name columns in lyris folowing these conventions: capitalize the first letter (and only the first letter) of each word, end separate words with underscores. Ex: Eclip, Education_Uk_Nursery, Sizzix_Uk_Dutch_Retailers etc.  
  NEWSLETTER_SEGMENTS = {"szus" => {:sizzix_scoop =>	"Sizzix Scoop", :sizzix_outlet =>	"Sizzix Outlet", :eclips => "eclips Consumer", :tim_holtz => "Tim Holtz Fan", :quilt_consumer => "Quilt Consumer", :sizzix_events => "Sizzix Events"},
    "szuk" => {:sizzix_uk_consumers => "Sizzix Newsletter", :eclips => "Sizzix eclips", :tim_holtz => "Tim Holtz"},
    "eeus" => {:connection => "Ellison Connection", :ellison_events => "Ellison Events"},
    "eeuk" => {:ellison_education_uk => "Education UK Newsletter", :back_to_school => "Back to School", :education_uk_nursery => "Education UK Nursery", :education_uk_primary => "Education UK Primary", :education_uk_secondary => "Education UK Secondary"},
    "erus" => {:erus_retailers => "Retailers Newsletter", :sizzix_retailers => "Sizzix Retailers", :ellison_retailers => "Ellison Retailers", :sizzix_retailers_in_spanish => "Sizzix Retailers in Spanish"}
  }
  
  def institutions
    [["Day Care 3 - 6 yrs", "DA"], ["District Media Center", "DM"], ["Head Start, Even Start", "HE"], ["Individuals-Teacher, Crafter, Designer", "IN"], ["Non-Profit Organization, Hospital", "NP"], ["Public Library", "PL"], ["School - Pre-School, Early Childhood Center", "SP"], ["School - Elementary", "SE"], ["School - Junior High", "SJ"], ["School - High School", "SH"], ["School - University", "SU"], ["School - Charter Elementary, Jr High, High", "SCHE"], ["School - Private", "PR"], ["School - Church", "SC"], ["School - District", "SD"], ["School - Government, Government Agency", "SG"]]
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
  
  def timeout_message
    "We are having technical difficulties. Please try again later or <a href='/contact'>contact</a> our customer service for help.".html_safe
  end

	def get_gateway(system = current_system)
	  system ||= current_system
    options = if system == 'szus'
              {:merchant_account => {
                 :name => 'cyber_source',
                 :user_name => 'sizzix',
                 :password => 'gjSlJTQJGbiPL5fAwVZ2ho0r98LmsYw1FOdGq675dIZzsASmsv5/M2kKhc3mwAtPGlVBAf12UVToDRYqcXpQJUtkXCvp1oDQ0RyqmQlTH9CGUGh3lR+7jVwJ5+8qokWtWnrYuUU3JDE4suev4jYGCQ9lutmXAmhH5+OpxGG84TRsV7APDoSoJM4UhtGpYnaGjSv3wuaxjDUU50arrvl0hnOwBKay/n8zaQqFzebAC08aVUEB/XZRVOgNFipxelAlS2RcK+nWgNDRHKqZCVMf0IZQaHeVH7uNXAnn7yqiRa1aeti5RTckMTiy56/iNgYJD2W62ZcCaEfn46nEYbzhNA==',
                 :login => 'sizzix'}}
            elsif system == 'eeus'
               {:merchant_account => {
                 :name => 'cyber_source',
                 :user_name => 'ellison',
                 :password => 'wpc4lHdGRv/Q8rXAmLy9bNdrZr2tTZdU5SypZVRb4Q2hapwjIIiYszLzcrQZG6R1fh+76JKLhlqIjeoY/Hzvfh2OD+/GQzUznEhn7HOk4rPWiLHQogY7ZpCCQNhEt2SCaeMjHrpg2ugpPvriX2MT7hPt8L2XeRddpYdIFUSL2Y/iLhCFg3CDVmQ4gUcYZ1Ns12tmva1Nl1TlLKllVFvhDaFqnCMgiJizMvNytBkbpHV+H7vokouGWoiN6hj8fO9+HY4P78ZDNTOcSGfsc6Tis9aIsdCiBjtmkIJA2ES3ZIJp4yMeumDa6Ck++uJfYxPuE+3wvZd5F12lh0gVRIvZjw==',
                 :login => 'ellison'}}
           elsif system == 'erus'
              {:merchant_account => {
                :name => 'cyber_source',
                :user_name => 'ellisonretail',
                :password => 'skoRfHH6Z9g5muYxQYau+F3xx6VpMvBgIiaYF7ehVa6Fi+oMmU2mG+naCHaPQvJ7maLAV+Fv8DHwUjvB755DujWNmRm0JK257S//v8Amf+coDwzBukjQIw3rwKmTribTW9swVYFeTNSzIe7PkHzkJdqVzSr6MyL1b1E5CditD6FSbqpYS9EwS+SDAfReWVUub1jHpWky8GAiJpgXt6FVroWL6gyZTaYb6doIdo9C8nuZosBX4W/wMfBSO8HvnkO6NY2ZGbQkrbntL/+/wCZ/5ygPDMG6SNAjDevAqZOuJtNb2zBVgV5M1LMh7s+QfOQl2pXNKvozIvVvUTkJ2K0PoQ==',
                :login => 'ellisonretail'}}
            else
               {:merchant_account => {
                 :name => 'sage_pay',
                 :user_name => 'ellison',
                 :password => 'ellisond',
                 :login => 'ellisonadmin'}}
             end
    config = GwConfig.new(options)
    ActiveMerchant::Billing::Base.mode = :test #unless Rails.env == 'production' 
    @gateway = ActiveMerchant::Billing::Base.gateway(config.name.to_s).new(:login => config.user_name.to_s, :password => config.password.to_s)    
  rescue
    raise 'Invalid ActiveMerchant Gateway'
  end
  
  class GwConfig
    attr_reader :name, :user_name, :password
    def initialize(config)
      raise "Please configure the ActiveMerchant Gateway" if config[:merchant_account] == nil
      @name = config[:merchant_account][:name].to_s
      @user_name = config[:merchant_account][:user_name].to_s
      @password  = config[:merchant_account][:password].to_s
    end
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
