require 'carrierwave/orm/mongoid'

class Product
	include EllisonSystem
	include ActiveModel::Validations
	#include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Versioning
	include Mongoid::Timestamps
 
	
	# validations
	validates :name, :item_num, :price, :msrp, :presence => true
	validates_uniqueness_of :item_num, :upc
  validates_numericality_of :price, :msrp, :greater_than => 0.0
	
	
	# field definitions
	field :name
	field :short_desc
	field :long_desc
	field :item_num
	field :upc
	field :quantity, :type => Integer, :default => 0
	field :active, :type => Boolean, :default => false
	field :deleted, :type => Boolean, :default => false
	field :availability, :type => Integer, :default => 0
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :images, :type => Array
	field :tabs, :type => Array # TODO: embeds_many :tabs
	field :life_cycle
	field :life_cycle_ends, :type => DateTime
	field :handling_price, :type => Float, :default => 0.0
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	scope :deleted, :where => { :deleted => true }
	scope :not_deleted, :where => { :deleted => false }

	LIFE_CYCLES = [nil, 'ComingSoon', 'New', 'Discontinued', 'Available', 'Clearance-Discontinued']
	
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => BigDecimal
	end
	ELLISON_SYSTEMS.each do |system|
		LOCALES_2_CURRENCIES.values.each do |currency|
			field "price_#{system}_#{currency}".to_sym, :type => BigDecimal
		end
	end

	mount_uploader :image, ImageUploader	
	
	def msrp(options = {})
		currency = options[:currency] || current_currency
		send("msrp_#{currency}") || send("msrp_usd")
	end

	def msrp=(p)
		send("msrp_#{current_currency}=", p)
	end
	
	def price(options = {})
		currency = options[:currency] || current_currency
		system = options[:system] || current_system
		send("price_#{system}_#{currency}") || msrp(options)
	end
	
	def price=(p)
		send("price_#{current_system}_#{current_currency}=", p)
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
			FileTest.exists?(image.default_url(version)) ? image.default_url(version) : "images/products/#{version}/noimage.jpg"
		end
	end
end