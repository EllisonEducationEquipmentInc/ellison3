class Coupon
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	LEVELS = %w( product order highest_priced_product shipping buy_one_get_another )
	
	field :name
	field :codes, :type => Array
	field :active, :type => Boolean, :default => true
	field :systems_enabled, :type => Array
	field :level
	field :discount_type, :default => "percent"
	field :discount_value, :type => Float, :default => 0.0
	field :products, :type => Array
	
	field :cart_must_have, :type => Array                               # ex: [{"any" => ["654395", "654396", "654397"], "all" => ["654380", "654381"]}]
	field :products_excluded, :type => Array, :default => []            # excluded product for order_has_to_be conditions. (these products will be excluded for weight and sub_total calculations)
	field :order_has_to_be, :type => Hash                               # ex: {"total_weight" => {:over => 10.0, :under => 100.0}, "sub_total" => {:over => 100.0}}
	field :shipping_country, :type => Array
	field :shipping_state, :type => Array
	
	ELLISON_SYSTEMS.each do |system|
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
	  field "description_#{system}".to_sym
	end
	
	index :systems_enabled
	index :codes
	index :active
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	
	references_many :carts

	validates :name, :codes, :systems_enabled, :level, :presence => true
	validates_inclusion_of :level, :in => LEVELS, :message => "extension %s is not included in the list"
	validates_inclusion_of :discount_type, :in => %w( percent absolute fixed ), :message => "extension %s is not included in the list"
	validates_numericality_of :discount_value
	
	before_save Proc.new {|obj| obj.order_has_to_be.delete_if {|k,v| v.delete_if {|k,v| v.blank?}.blank?}}
	
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
	
	def description(options = {})
		system = options[:system] || current_system
		send("description_#{system}") || send("description_er") || send("description_szus")
	end
	
	def description=(d)
		send("description_#{current_system}=", d) unless d.blank? || d == description_er
	end
	
	def product_item_nums
		read_attribute(:products).try :join, ", "
	end
	
	def product_item_nums=(product_item_nums)
		write_attribute(:products, product_item_nums.split(/,\s?/)) unless product_item_nums.nil?
	end
end