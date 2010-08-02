class Campaign
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	# include Mongoid::Versioning
	# include Mongoid::Timestamps
	# include Mongoid::Paranoia
	
	DISCOUNT_TYPES = [["Percent", 0], ["Absolute", 1], ["Fixed", 2]]
	
	# field definitions
	field :name
	field :code
	field :short_desc
	field :active, :type => Boolean, :default => false
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :discount, :type => Float, :default => 0.0
	field :discount_type, :type => Integer, :default => 0
	field :systems_enabled, :type => Array
	
	# associations
	embedded_in :product, :inverse_of => :campaigns
	
	def available?(time = Time.zone.now)
		Rails.logger.info "#{systems_enabled.inspect} #{current_system} #{systems_enabled.include?(current_system)}"
		start_date <= time && end_date >= time && active && systems_enabled.include?(current_system)
	end
	
	def sale_price
		return unless product
		if discount_type == 0
			product.base_price - (0.01 * discount * product.base_price).round(2)
		elsif discount_type == 1
			product.base_price - discount
		elsif discount_type == 2
			discount
		end
	end
	
end