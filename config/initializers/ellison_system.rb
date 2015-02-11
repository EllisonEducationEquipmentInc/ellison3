module EllisonSystem
  
	# define which locale has what currency
	LOCALES_2_CURRENCIES = {'en-US' => 'usd', 'en-UK' => 'gbp', 'en-EU' => 'eur'} unless const_defined?(:LOCALES_2_CURRENCIES)
	
	# define systems here
	ELLISON_SYSTEMS = %w(szus szuk eeus eeuk erus) unless const_defined?(:ELLISON_SYSTEMS)
	
	WAREHOUSES = %w(us uk sz)
	
	MACHINES = {"A10000" => "AllStar", "A10800" => "AllStar SuperStar", "655210" => "BIGkick", "655268" => "Big Shot", "655750" => "Big Shot Express", "656250" => "Big Shot Pro", "655934" => "eclips", "15569" => "LetterMachine Original", "15575" => "LetterMachine XL", "19101" => "Prestige Pro", "19528" => "Prestige Select", "19356" => "Prestige SpaceSaver", "26868" => "RollModel", "655397" => "Sidekick", "38-0605" => "Sizzix Original Machine",  "656225" => "Texture Boutique", "656850" => "Vagabond", "none" => "None of the above"}
	
	MULTIFACETS = true #false

  MAX_CART_VALUE = 100000
  MAX_ITEMS = 99
  MAX_PER_ITEM = 20
  MAX_WEIGHT = 5000
  MIN_ORDER = 0.01
  ER_MIN_ORDER = 100
  ER_FIRST_MIN_ORDER = 300
  ITEMS_FOR_THREE_EASY_PAYMENTS = ["655934", "29851", "29914", "657500", "656250", "656820", "656850", "657700","29944","29945","29946","657550","657600"]
  
  @@disable_solr_indexing = false
  
  def disable_solr_indexing?
    @@disable_solr_indexing
  end
  
  def disable_solr_indexing!
    @@disable_solr_indexing = true
  end
  
  def enable_solr_indexing!
    @@disable_solr_indexing = false
  end
  
  def backorder_allowed?(sys = current_system)
    sys == 'erus' || sys == 'eruk' || sys == 'eeuk'
  end

  def can_place_quote_on_backordered?(sys = current_system)
    backorder_allowed?(sys) || sys == "eeus"
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
  
  def is_er_us?
    is_er? && is_us?
  end
  
  def is_er_uk?
    is_er? && is_uk?
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
	
	def system_to_domain(sys)
	  {"szus" => "sizzix.com",  "szuk" => "http://www.sizzix.co.uk", "eeus" => "ellisoneducation.com", "eeuk" => "ellisoneducation.co.uk", "erus" => "ellisonretailers.com"}[sys]
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
	  is_sizzix? || is_er? ? 'sizzix' : 'ellison'
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
  # removed outlet segment for szus on feb 22nd 2012 :sizzix_outlet =>	"Sizzix Outlet", removed :sizzix_events => "Sizzix Events" on June 20th 2012 
  NEWSLETTER_SEGMENTS = {"szus" => {:sizzixscoop =>	"The Sizzix Scoop Newsletter", :cardmaking => "Cardmaking", :eclips => "Electronic Cutting", :fashion => "Fashion", :home_decor => "Home Decor", :jewelry => "Jewelry",:papercrafting => "Papercrafting", :quilt_consumer => "Quilting & Applique", :scrapbooking => "Scrapbooking"},
    "szuk" => {:sizzix_uk_consumers => "The Sizzix.co.uk Newsletter", :applique => "Applique", :cardmaking => "Cardmaking", :papercrafting => "Papercrafting", :quilt_consumer => "Quilting", :scrapbooking => "Scrapbooking"},
    "eeus" => {:connection => "The Ellison Connection Newsletter"},
    "eeuk" => {:ellison_education_uk => "The Ellisoneducation.co.uk Newsletter"},
    # "eeuk" => {:ellison_education_uk => "The Ellisoneducation.co.uk Newsletter", :back_to_school => "Back to School", :education_uk_nursery => "Education UK Nursery", :education_uk_primary => "Education UK Primary", :education_uk_secondary => "Education UK Secondary"},
    "erus" => {:erus_retailers => "The Retailers Newsletter", :sizzix_retailers => "Sizzix Retailers", :eclips => "Sizzix eclips", :tim_holtz => "Tim Holtz", :quilt_consumer => "Quilting", :ellison_retailers => "Ellison Retailers", :sizzix_retailers_in_spanish => "Sizzix Retailers in Spanish"}
  }
  
  def list_to_system(list)
    NEWSLETTER_SEGMENTS.select {|k,v| v.keys.include?(list.to_sym)}.keys.first rescue nil
  end
  
  def get_list_and_segments
    @segments = NEWSLETTER_SEGMENTS[current_system].dup
    @list = @segments.shift
  end
  
	def lyris_email
    lyris_email = case current_system
      when "szus" then "sizzixscoop@lyris.sizzix.com"
      when "szuk" then "sizzix_uk_consumers@lyris.sizzix.co.uk"
      when "eeus" then "connection@lyris.ellison.com"
      when "eeuk" then "ellison_education_uk@lyris.ellison.com"
      when "erus" then "erus_retailers@ellison.com"
      else "erus_retailers@ellison.com"
    end    
    return lyris_email
	end

  # new_lyris_email is added temporarily on April 17 2013, need to remove once new lyris sign-up static pages are launched
	def new_lyris_email
    new_lyris_email = case current_system
      when "szus" then "sizzixscoop@marketing.sizzix.com"
      when "szuk" then "sizzixinteractivenews@marketing.sizzix.co.uk"
      when "eeus" then "connection@marketing.ellisoneducation.com"
      when "eeuk" then "EducationNews@marketing.ellisoneducation.co.uk"
      when "erus" then "ellison_retail_news@marketing.ellison.com"
      else "ellison_retail_news@marketing.ellison.com"
    end    
    return new_lyris_email
	end
  
  def all_lyris_lists
    NEWSLETTER_SEGMENTS.values.map {|e| e.keys.first.to_s}
  end

  
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
  
  def cc_sales_rep?
    is_ee? || is_er?
  end
  
  def timeout_message
    "Sorry! We are experiencing technical difficulties. Please try again later or contact customer service for assistance."
  end

  def gateway_options(system = current_system)
    # Production credentials updated on Feb 11 2015
    if Rails.env.production?
      if system == 'szus'
        {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'sizzix',
           :password => 'MocJKd3mtvbymm5pYn5JIU7/SqXqwvSWdoU+2VxXuDnCiYiqnp9rDRUr9QMuFFOXg9LcmZlnPt64A00xX0wGtqEcN159rp90dtnJQBkpJ4cG4X3TY8bPEyiKefvhhSH9QXUG8MnHsBM+sjGszpyKXZQpQENWUpn3+TgSDjIA8jIORA9V2n9ooe0zk5+mo70MoIMGgtf5J07xGS1MxvRjOvI6x42AUmPrJyKoWSbFbicCjttEZmkd9PFjxxd84mvvLIcysObI7F40hFTt1qP4cJ45UDyo0vQaGcOp1pYckJEyHOdkp1U4yWeYxh/QyHQG+M7SCOdG5KdMjvChHhZpZw==',
           :login => 'sizzix'}}
      elsif system == 'eeus'
         {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'ellison',
           :password => 'br9xXm585nrId72GOl4L8+P1GMQQaPjF4764RHoUTk9f58srmbVK8xzFFOxlHfH4CFn0HLv/ybwf8mAO1A5L6wY6ujkQdGtMTRKttm6jD1RgaOxWJo+sNyLUUMK4TzXxAqwVuH1ie2g+AZbKVXV5lML7THk/HVCXUeO1zum1KsIeSwHoYMvB4MZ3x0q4GtuJe7IWkINqf2vAYAvy+TTxnKYI02WRj4q5Js45l50hneUoGUrpd7tgUOcGPhpyaPw/3pPDsc7Uazx1PSm6VhBsXj2Zi87oc7+IybnQUB2SvMDCp0HvTl7rAzXHWpeYaEN0XkpzODqgxnv5DvrgojRz2g==',
           :login => 'ellison'}}
      elsif system == 'erus'
        {:merchant_account => {
          :name => 'cyber_source',
          :user_name => 'ellisonretail',
          :password => 'lpeqwQtW33B+pHzEjClDxDalsR5Tr9r53gXzkKUM9UmBcnlNADh89leU6fZst2fJPdAuYjj0gI34qJyiQexgxw6NtlyOXl0nku7+q9RpUp6lwIg9rbuF0NOtIdM3GiLDqxfArd9Gw6Up0Ev+jrbAUjBXP55OMnSwRfADBwTBkGdMS7GO9Wt3YsG30Cq+Ft5Kgntro0LL0qFqPTXbO4CMcWmqpiuOsb2pS17waVGqNOU5g9J8DJABC6vMGiwB436G4lvxe1zBo08vlq9xRAUcmc1EpBrF6Ih5gksr0nzODbzBtzSDAc7v6nGVLI/iq/xsmkUYV9RFa0GIZra0OERIag==',
          :login => 'ellisonretail'}}
      else
         {:merchant_account => {
           :name => 'sage_pay',
           :user_name => 'ellison',
           :password => 'ellisond',
           :login => 'ellisonadmin'}}
      end

    # development, test, staging
    else
      if system == 'szus'
        {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'sizzix',
           :password => 'tiGfqAWKZc5/MNB3zBkPGa/HtGtotIhqTD8PKtilnwG9MPqVcMsd0ZSv+vqTOTrRI/qtkPUP7w1y9VLwmsn5K7LZ+vbmiDGdUM3EKxdjOouQtCx59h1A6VkQqT3o8jt/ITZbInyZ4u319zjAtyqVOXCfVwlej7bBeScOnHtjzUrt1XMDrJoEUPdBva/hn3FFBmDIU0u9TIAR9xokK+2oSKphhxH9zcCuZqx2pp00EYw9y9WE/0C9rH5KMveu5/oz34ZjmZnsfZQir46KOXpQEvEsgTx387xPcRFjk3zCMZnTnmzxJX0jLdADoELW1hO+1y5x5VB6GydrPIWEl2eogQ==',
           :login => 'sizzix'}}
      elsif system == 'eeus'
         {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'ellison',
           :password => 'rYHrAw8LDXZm3q0CfxGGZGY3vkqDFPhsTbd8OBneFHpLMlXPQwXuPcODjsnr4f79nprF0l+BnPLN0/8lErPhp7i9sD5T5MmZlR66a/CEb+ooGk70olbOtDPwApUnQwf/YpbzwRfWqCOm9HGGj/cT3feJoZKxF5pCLuM5+Fj4iRZR6zNXDzz7iWFPSzy+hdnLkJqCSXp2qIVBUYe01dNdIqeiuzX5rCisfKqLtHnDXFMCi+05w/NEP4oiURIkFrWl0IT+fukLBrLrvKVOTtdh2wR7lNqjKkMtOYMXJVAg/TmkdLnzJS4MUHUXMhLu1rjIkveCePzICIxUzxvy7/rVOA==',
           :login => 'ellison'}}
      elsif system == 'erus'
        {:merchant_account => {
          :name => 'cyber_source',
          :user_name => 'ellisonretail',
          :password => 'LeM8l33rWc+zPLzSklp5tOZMm0bqQGYkTpCHwMMh5ZrRezV4SrOqRLZcCIxo0+y/iPpGByMuuOOsS84B+6A2NRNROidkdbeqcm+TSAKjqm+C/xtIGaV9qdfNkudLqNjMwYSTbDm4ZjjTBzWKwk+eU6HLepqbEfto43WNXoL1+yv6T9v8/dEncCCxHhqC/rdEz0W2NsNLrChumpecaUmBWG7eqo3UK8v1UmiWLMeoLFdAFvdVgQeliDOyjlAP1bui6J3duXCPQTRqw0lwWTd4xqlto0Hw+qbcoIJFcimAOkI6HO2KnxsqtijH7939WhpOn1ovLCGqGWgcw1qYMihLWA==',
          :login => 'ellisonretail'}}
      else
         {:merchant_account => {
           :name => 'sage_pay',
           :user_name => 'ellison',
           :password => 'ellisond',
           :login => 'ellisonadmin'}}
      end
    end
  end

	def get_gateway(system = current_system)
	  system ||= current_system
    options = gateway_options(system)
    config = GwConfig.new(options)
    ActiveMerchant::Billing::Base.mode = :test unless Rails.env == 'production' 
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

ActionDispatch::ShowExceptions.class_eval do 
  include EllisonSystem
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
