require 'carrierwave/orm/mongoid'

class Product
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Versioning
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	# To have all queries for a model "cache":
  #cache
	
	# validations
	validates :name, :item_num, :msrp, :price, :start_date, :end_date, :systems_enabled, :presence => true
	validates_uniqueness_of :item_num
	validates_uniqueness_of :upc, :allow_blank => true
  validates_numericality_of :msrp, :price, :greater_than => 0.0
	
	
	# field definitions
	field :name
	field :short_desc
	field :long_desc
	field :item_num
	field :upc
	field :quantity, :type => Integer, :default => 0
	field :active, :type => Boolean, :default => false
	field :availability, :type => Integer, :default => 0
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :images, :type => Array
	field :tabs, :type => Array # TODO: embeds_many :tabs
	field :life_cycle
	field :life_cycle_ends, :type => DateTime
	field :handling_price, :type => Float, :default => 0.0
	field :systems_enabled, :type => Array

	index :item_num, :unique => true, :background => true
	index :systems_enabled
	
	# associations
	embeds_many :campaigns do
    def current(time = Time.zone.now)
			@target.select {|campaign| campaign.available?(time)}
    end
  end
		
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	LIFE_CYCLES = [nil, 'ComingSoon', 'New', 'Discontinued', 'Available', 'Clearance-Discontinued']
	
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => BigDecimal
	end
	ELLISON_SYSTEMS.each do |system|
		field "description_#{system}".to_sym
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
		base_price(options) > campaign_price(time) ? campaign_price(time) : base_price(options)
	end
	
	def price=(p)
		send("price_#{current_system}_#{current_currency}=", p) unless p.blank?
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

private 
	def get_image(version)
		if image?
			image_url(version)
		else
			FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}") ? image.default_url(version) : "/images/products/#{version}/noimage.jpg"
		end
	end
end