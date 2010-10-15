class Coupon
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :name
	field :codes, :type => Array
	field :active, :type => Boolean, :default => true
	field :description
	field :systems_enabled, :type => Array
	field :level
	field :discount_type, :default => "percent"
	field :discount_value, :type => Float, :default => 0.0
	field :products, :type => Array
	
	field :cart_must_have, :type => Hash
	field :products_excluded, :type => Array
	field :order_has_to_be, :type => Hash
	field :shipping_country, :type => Array
	field :shipping_state, :type => Array
	
	index :systems_enabled
	index :codes
	index :active
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	
	references_many :carts
	
	ELLISON_SYSTEMS.each do |system|
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
	end
	
	validates :name, :codes, :systems_enabled, :level, :presence => true
	validates_inclusion_of :level, :in => %w( product order highest_priced_product, shipping buy_one_get_another ), :message => "extension %s is not included in the list"
	validates_inclusion_of :discount_type, :in => %w( percent absolute fixed ), :message => "extension %s is not included in the list"
	validates_numericality_of :discount_value
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self		
		def available
			active.send(current_system).where(:"start_date_#{current_system}".lte => Time.zone.now, :"end_date_#{current_system}".gte => Time.zone.now)
		end
	end
	
	# discount types: percent, absolute, fixed
	# levels: product, order, highest_priced_product, shipping, buy_one_get_another
	def product?
	  self.level == "product" && !self.products.blank?
	end
	
	def order?
	  self.level == "order"
	end
	
	def highest_priced_product?
	  self.level == "highest_priced_product"
	end
	
	def shipping?
	  self.level == "shipping"
	end
	
	def buy_one_get_another?
	  self.buy_one_get_another == "buy_one_get_another"
	end
end