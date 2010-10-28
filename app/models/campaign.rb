class Campaign
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	# include Mongoid::Versioning
	# include Mongoid::Timestamps
	# include Mongoid::Paranoia
		
	DISCOUNT_TYPES = [["Percent", 0], ["Absolute", 1], ["Fixed", 2]]
	
	# validations
	validates :name, :discount, :discount_type, :start_date, :end_date, :systems_enabled, :presence => true
	validates_numericality_of :discount, :greater_than => 0.0
	validates_associated :individual_discounts
	
	# field definitions
	field :name
	field :code
	field :short_desc
	field :active, :type => Boolean, :default => true
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :discount, :type => Float, :default => 0.0
	field :discount_type, :type => Integer, :default => 0
	field :systems_enabled, :type => Array
	field :individual, :type => Boolean, :default => false
	
	# associations
	embedded_in :product, :inverse_of => :campaigns
	embedded_in :tag, :inverse_of => :campaign
	embeds_many :individual_discounts
	
	accepts_nested_attributes_for :individual_discounts, :allow_destroy => true
		
	def available?(time = Time.zone.now)
		start_date <= time && end_date >= time && active && systems_enabled.include?(current_system)
	end
	
	def discount_name
		DISCOUNT_TYPES[discount_type][0]
	rescue
		nil	
	end
	
	def sale_price
		return unless product
		if discount_type == 0
			product.base_price - (0.01 * discount * product.base_price).round(2)
		elsif discount_type == 1
			product.base_price - discount > 0 ? product.base_price - discount : 0.0
		elsif discount_type == 2
			discount
		end
	end
	
end