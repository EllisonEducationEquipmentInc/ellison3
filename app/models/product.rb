require 'carrierwave/orm/mongoid'
require 'digest/sha1'

class Product
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	# NOTE: to be able to skip Versioning and/or Timestamps, use my patched mongoid: git://github.com/computadude/mongoid.git
	include Mongoid::Versioning
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	# To have all queries for a model "cache":
  #cache
	
	max_versions 5
	
	QUANTITY_THRESHOLD = 0
	LIFE_CYCLES = ['pre-release', 'available', 'discontinued', 'unvailable']
	
	# validations
	validates :name, :item_num, :life_cycle, :systems_enabled, :presence => true
	validates_inclusion_of :life_cycle, :in => LIFE_CYCLES, :message => "%s is not included in the list"
	validates_uniqueness_of :item_num
	validates_uniqueness_of :upc, :allow_blank => true
	validate :must_have_msrp
	
	before_save :inherit_system_specific_attributes
	
	# system specific validations
	ELLISON_SYSTEMS.each do |system|
	  validates :"start_date_#{system}", :"end_date_#{system}",  :presence => true, :if => Proc.new {|p| current_system == system}
	end
		
	cattr_accessor :current_user
  cattr_accessor :custom_prices
  cattr_accessor :highest_item_in_cart
	
	# field definitions
	field :name
	field :short_desc
	field :long_desc
	field :item_num
	field :upc
	field :quantity, :type => Integer, :default => 0
	field :weight, :type => Float, :default => 0.0
	field :active, :type => Boolean, :default => true
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :life_cycle
	field :systems_enabled, :type => Array
	field :tax_exempt, :type => Boolean, :default => false
	
	index :item_num, :unique => true, :background => true
	index :systems_enabled
	#index :life_cycle
	
	# associations
	embeds_many :campaigns do
    def current(time = Time.zone.now)
			@target.select {|campaign| campaign.available?(time)}
    end
  end
	embeds_many :tabs do
    def current
			@target.select {|tab| tab.available?}.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
	embeds_many :images
		
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self
		
		# TODO: add start/end date logic
		def available
			active.where(:availability.in => [1,3])
		end
		
	end
		
	# define 
	#   system dependent attributes: start_date, end_date, description, distribution_life_cycle, distribution_life_cycle_ends, pre_order, orderable, orderable_start_date
	#   currency dependent attributes: msrp, handling_price
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => BigDecimal
		field "handling_price_#{currency}".to_sym, :type => Float, :default => 0.0
	end
	ELLISON_SYSTEMS.each do |system|
	  field "orderable_#{system}", :type => Boolean
	  #field "orderable_start_date_#{system}".to_sym, :type => DateTime
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
		field "description_#{system}".to_sym
		field "distribution_life_cycle_#{system}".to_sym
	  field "distribution_life_cycle_ends_#{system}".to_sym, :type => DateTime
	  field "availability_message_#{system}"
		LOCALES_2_CURRENCIES.values.each do |currency|
			field "price_#{system}_#{currency}".to_sym, :type => BigDecimal
		end
	end

	mount_uploader :image, ImageUploader	
	
	def description(options = {})
		system = options[:system] || current_system
		send("description_#{system}") || send("description_er") || send("description_szus")
	end
	
	def description=(d)
		send("description_#{current_system}=", d) unless d.blank? || d == description_er
	end
	
	def msrp(options = {})
		currency = options[:currency] || current_currency
		send("msrp_#{currency}") || send("msrp_usd")
	end

	def handling_price=(p)
		send("handling_price_#{current_currency}=", p) unless p.blank?
	end
	
	def handling_price(options = {})
		currency = options[:currency] || current_currency
		send("handling_price_#{currency}") || send("handling_price_usd") || 0.0
	end

	def msrp=(p)
		send("msrp_#{current_currency}=", p)
	end
	
	def base_price(options = {})
		currency = options[:currency] || current_currency
		system = options[:system] || current_system
		send("price_#{system}_#{currency}") || msrp(options)
	end
	
	def price(options = {})
		time = options[:time] || Time.zone.now
		campaign_price(time) && base_price(options) > campaign_price(time) ? campaign_price(time) : base_price(options)
	end
	
	def price=(p)
		send("price_#{current_system}_#{current_currency}=", p) unless p.blank?
	end
	
	def custom_price
    @custom_price ||= custom_prices[id]
  end
  
  def custom_price=(p)
    @custom_price = p.to_f.round_to(2)
  end

	def campaign_price(time = Time.zone.now)
		get_best_campaign(time).try :sale_price
	end

	alias :sale_price :campaign_price
	
	def get_best_campaign(time = Time.zone.now)
		campaigns.current(time).sort {|x,y| x.sale_price <=> y.sale_price}.first
	end
	
	def medium_image
		get_image(:medium)
	end
	
	def small_image
		get_image(:small)
	end
	
	def large_image
		get_image(:large)
	end	
	
	# available for purchase on the website?
	def available?
		start_date < Time.now && end_date > Time.now && availability == 1
	end
	
	def not_reselable?
	  start_date < Time.now && end_date > Time.now && availability == 3
	end
	
	def unavailable?
		!available? || out_of_stock?
	end
	
	def update_quantity(qty)
		skip_versioning_and_timestamps
		update_attributes :quantity => qty
	end
	
	def decrement_quantity(qty)
		skip_versioning_and_timestamps
		update_attributes :quantity => self.quantity - qty
	end
	
	def in_stock?
    quantity > QUANTITY_THRESHOLD
  end
  
  def out_of_stock?
    !in_stock?
  end

	def pre_order?
		is_er? && available? && pre_order
	end
	
	# TODO: system specific logic for availability_msg
	def availability_msg
		"availability_msg"
	end


private 

  # automatically set system specific attributes (if not set) of all other enabled systems. Values are inherited from the current system
  # example: a new product is being created on SZUS. The new product will be pushed to szus and szuk. Those 2 systems are checked on the product admin form, and before save, SZUK will inherit the same attributes (which can be overridden by switching to szuk) 
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      self.send("start_date_#{sys}=", read_attribute("start_date_#{current_system}")) if read_attribute("start_date_#{sys}").blank?
      self.send("end_date_#{sys}=", read_attribute("end_date_#{current_system}")) if read_attribute("end_date_#{sys}").blank?
      self.send("orderable_#{sys}=", read_attribute("orderable_#{current_system}")) if read_attribute("orderable_#{sys}").blank?
      self.send("availability_message_#{sys}=", read_attribute("availability_message_#{current_system}")) if read_attribute("availability_message_#{sys}").blank?
    end
  end

  def must_have_msrp
    errors.add(:msrp, "Make sure MSRP is defined for all available currencies in system #{current_system.upcase}") if currencies.any? {|c| self.send("msrp_#{c}").blank? || self.send("msrp_#{c}") < 0.01}
  end
  
	def get_image(version)
		if image?
			image_url(version)
		else
			FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}") ? image.default_url(version) : "/images/products/#{version}/noimage.jpg"
		end
	end
	
	# NOTE: needs git://github.com/computadude/mongoid.git
	def skip_versioning_and_timestamps
		self._skip_timestamps = self._skip_versioning = true
	end
end