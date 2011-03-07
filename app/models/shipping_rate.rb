class ShippingRate
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "price_min_#{currency}".to_sym, :type => Float
		field "price_max_#{currency}".to_sym, :type => Float
		field "standard_rate_#{currency}".to_sym, :type => Float
		field "rush_rate_#{currency}".to_sym, :type => Float
	end
	field :system
	field :zone_or_country
	
	field :created_by
	field :updated_by
	
	validates :system, :zone_or_country, :presence => true
	validates_inclusion_of :system, :in => ELLISON_SYSTEMS
	validate :range_and_rate_must_be_set_for_all_currencies 
	
	def initialize(attrs = nil)
	  super
	  self.system ||= current_system
	end
    
  index :system
  index :zone_or_country
  LOCALES_2_CURRENCIES.values.each do |currency|
		index "price_min_#{currency}".to_sym
		index "price_max_#{currency}".to_sym
	end
	index :updated_at
  

private
	
	def range_and_rate_must_be_set_for_all_currencies
	  currencies(self.system).each do |currency|
	    errors.add("price_min_#{currency}", "can't be blank, and must be a number") if send("price_min_#{currency}").blank? || !send("price_min_#{currency}").is_a?(Float)
	    errors.add("price_max_#{currency}", "can't be blank, and must be a number") if send("price_max_#{currency}").blank? || !send("price_max_#{currency}").is_a?(Float)
	    errors.add("standard_rate_#{currency}", "can't be blank, and must be a number") if send("standard_rate_#{currency}").blank? || !send("standard_rate_#{currency}").is_a?(Float)
	    #errors.add("rush_rate_#{currency}", "can't be blank, and must be a number") if send("rush_rate_#{currency}").blank? || !send("rush_rate_#{currency}").is_a?(Float)
	  end
	end
	
end
