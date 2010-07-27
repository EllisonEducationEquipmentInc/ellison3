class Product
	include EllisonSystem
	include ActiveModel::Validations
	#include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Versioning
	include Mongoid::Timestamps

	# validations
	validates :name, :item_num, :price, :presence => true
	
	# field definitions
	field :name
	field :short_desc
	field :long_desc
	field :item_num
	field :quantity, :type => Integer, :default => 0
	field :active, :type => Boolean, :default => false
	field :deleted, :type => Boolean, :default => false
	field :availability, :type => Integer, :default => 0
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :small_image
	field :medium_image
	field :images, :type => Array
	field :tabs, :type => Array # TODO: embeds_many :tabs
		
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => BigDecimal
	end
	ELLISON_SYSTEMS.each do |system|
		LOCALES_2_CURRENCIES.values.each do |currency|
			field "price_#{system}_#{currency}".to_sym, :type => BigDecimal
		end
	end
	
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

end