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
	
	# validations
	validates :name, :item_num, :msrp, :price, :start_date, :end_date, :systems_enabled, :presence => true
	validates_uniqueness_of :item_num
	validates_uniqueness_of :upc, :allow_blank => true
  validates_numericality_of :msrp, :price, :greater_than => 0.0
	
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
	field :active, :type => Boolean, :default => false
	field :availability, :type => Integer, :default => 0
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :life_cycle
	field :life_cycle_ends, :type => DateTime
	field :systems_enabled, :type => Array
	field :tax_exempt, :type => Boolean, :default => false
	field :pre_order, :type => Boolean, :default => false
	
	index :item_num, :unique => true, :background => true
	index :systems_enabled
	index :availability
	
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
	
	LIFE_CYCLES = [nil, 'ComingSoon', 'New', 'Discontinued', 'Available', 'Clearance-Discontinued']
	
	# define 
	#   system dependent attributes: start_date, end_date, description, life_cycle, life_cycle_ends
	#   currency dependent attributes: msrp, handling_price
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => BigDecimal
		field "handling_price_#{currency}".to_sym, :type => Float, :default => 0.0
	end
	ELLISON_SYSTEMS.each do |system|
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
		field "description_#{system}".to_sym
		field "life_cycle_#{system}".to_sym
	  field "life_cycle_ends_#{system}".to_sym, :type => DateTime
		LOCALES_2_CURRENCIES.values.each do |currency|
			field "price_#{system}_#{currency}".to_sym, :type => BigDecimal
		end
	end

	mount_uploader :image, ImageUploader	
	
	def description(options = {})
		system = options[:system] || current_system
		send("description_#{system}") || send("description_er")
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