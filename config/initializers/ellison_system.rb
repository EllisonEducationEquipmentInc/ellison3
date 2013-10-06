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

  def lyrishq_settings
    if is_sizzix_us?
      {ml_id: '1742', site_id: '2012000352'}
    else
      {ml_id: '1742', site_id: '2012000352'}
    end
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
    # Production
    if Rails.env.production?
      if system == 'szus'
        {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'sizzix',
           :password => 'NVb8EJQOhgBktwCaSSQCyQ/Vg2rDSbXlpdn9FDycbRHQkWmRd6AX5SsLK5g5k7sft0BhcJStSafgCb8h3AH9sogEFZfq5kn1bWvcQsPGBg1R03oQDLvz0u78pdb2lqEg19DsTHMJWr1Ql1iqm7x86aZDs2A+ryBjb+4Bs54DVrLhqF+a1KmMe1iaZzdGmNaia1DHbVueMwOMS+A2GYfSy8cVVxDAEeyp8Hao+U+H+nT4n5wH9jzBMEaY0KoxGn6U8aCMpJM4LSFGi2eWd05+kfL4Jj6WB8lhxwL/d7ZlH/JhxTGr0F9lcuUttN9+nUfkT899ffQ8rJdEOwyKkVKfcg==',
           :login => 'sizzix'}}
      elsif system == 'eeus'
         {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'ellison',
           :password => 'BpPtot9m0tKahzNosKGmdeCQeUkeaN8vKx8vOcJtLlUV+eqjELk7bFUR2owrRdf8PhQlp62zms4cVROaVuZXnpHN5PMRfrYG6ovp9V0Qfnw0EU87aHOWjdo5rXr+1LNyFCU8iZRniIn3ZIGvVMVW8QO/2zp+qCadKdXika1TEK8CTzg0E+m87q0x9vlPh/p0+J+cB/Y8wVmb6dQ7psXnkqYeWEsqzDz5MotnlndOfpHy+Cao80jCuusGCGetFjF1jkWGq9BfZXLlLbTffp1H5E/PfX30PKyXRDsMipFSn3KzsDv6Ywgpi0AtDKlsVHsbHtp0Mg7ZiH6p3WBfqDFkgg==',
           :login => 'ellison'}}
      elsif system == 'erus'
        {:merchant_account => {
          :name => 'cyber_source',
          :user_name => 'ellisonretail',
          :password => 'v1pBkChVavoz3XPXCMRW8ewXMMDfW70ldwLWp4AAtNHkG00sxaUM/HVo68yhhoJStUo2wtu1mhb54dEJKTWmdeCQeUkeaN8vKx8vOcJtLlUV+eqjELk7bFUR2owrRdf8PhQlp62zms4cVROaVuZXnpHN5PMRfrYG6ovp9V0Qfnw2wdYoR55Q6O9NONckGcjm9cR/4Ro+jRTLzCr54dEJKTWmdeCQeUkeaN8vKx8vOcJtLlUV+eqjELk7bFUR2owrRdf8PhQlp62zms4cVROaVuZXnpEZt/g92j+Xi2DQeV0Qfnw0UsRt/uF4ZslZMYzlmLIDgMHs5XVYnYg5HIGvVA==',
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
           :password => 'DcbG3+LXRV0AZwkAGaEpZ+n/OzSJWBhONwBsZrq/N20PGDIAlJ2t+rlpR+sjgOaaf7C62QLZa4VQ3QbTUkYNJIo3u9ZQCt71VLUTYMSpWV9u/tlMUH5aPAvlx6VpMvBgsf8Gdvx1fA2n79o6iCyTIgCmZnaPQvLTOXt+7asTYyV46eykp+7NhHyUBpTfqu1yQDs0iVgYTjcAbGa6vzdtDxgyAJSdrfq5aUfrI4Dmmn+wutkC2WuFUN0G01JGDSSKN7vWUAre9VS1E2DEqVlfbv7ZTFB+WjwL5celaTLwYLH/Bnb8dXwNp+/aOogskyIApmZ2j0Ly0zl7fu2rE2MlCQ==',
           :login => 'sizzix'}}
      elsif system == 'eeus'
         {:merchant_account => {
           :name => 'cyber_source',
           :user_name => 'ellison',
           :password => 'XS1C/PNJ9186uPcFAASCAmAwggJcAtIoyhjq9k5w/lSZIkBRg/CgVI4UCKvj1ogLj1TyBdl/D3vUcLUY/z6NghgkvDpYXWFjqSTgEBncr0+ml7oFXWNSATBP1lg3og5azfHDnob0HQrN/1NHbzFPpLgyqyJC/vj7Zm+XyhMdKB7VrFVOHvo97xcLWQUABIICYDCCAlwC0ijKGOr2TnD+VJkiQFGD8KBUjhQIq+PWiAuPVPIF2X8Pe9RwtRj/Po2CGCS8OlhdYWOpJOAQGdyvT6aXugVdY1IBME/WWDeiDlrN8cOehvQdCs3/U0dvMU+kuDKrIkL++Ptmb5fKEx0oHg==',
           :login => 'ellison'}}
      elsif system == 'erus'
        {:merchant_account => {
          :name => 'cyber_source',
          :user_name => 'ellisonretail',
          :password => 'HAuGLyXLCPduJIPyXpDMO4oImTKrIkL++Ptmb5fKEx0oHl4XlRBdxhUTtWV4+Eshb9WNEw7PZwZjfIGGIOsCAwEAAQKB6WeDiH3/JIStG+ZE6NymVzc4qMBUJviNWv8JQ3ybMhtPD+6AFUCteoIr7+E2GDp4oWkaHeI2BgkPZbpEmlbKcNivXKJK6sxKDKxNHt5BMqsiQv74+2Zvl8oTHSgeXheVEF3GFRO1ZXj4SyFv1Y0TDs9nBmN8gYYg6wIDAQABAoHpZ4OIff8khK0b5kTo3KZXNziowFQm+I1a/wlDfJsyG08P7oAVQK16givv4TYYOnihaRod4jYGCQ9lug==',
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
