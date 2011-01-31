class Coupon
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	COUPON_ITEM_NUM = "coupon23ew323dsd3d"   # coupon as line item disabled
	
	LEVELS = %w( product order highest_priced_product shipping  )
	DISCOUNT_TYPES = %w( percent absolute fixed )
	
	field :name
	field :codes, :type => Array
	field :no_code_required, :type => Boolean, :default => false
	field :active, :type => Boolean, :default => true
	field :systems_enabled, :type => Array
	field :level
	field :discount_type, :default => "percent"
	field :discount_value, :type => Float, :default => 0.0
	field :products, :type => Array
	field :free_shipping, :type => Boolean, :default => false
	
	field :cart_must_have, :type => Array                               # ex: [{"any" => ["654395", "654396", "654397"], "all" => ["654380", "654381"]}]
	field :products_excluded, :type => Array, :default => []            # excluded product for order_has_to_be conditions. (these products will be excluded for weight and sub_total calculations)
	field :order_has_to_be, :type => Hash                               # ex: {"total_weight" => {:over => 10.0, :under => 100.0}, "sub_total" => {:over => 100.0}}
	field :shipping_countries, :type => Array
	field :shipping_states, :type => Array
	
	ELLISON_SYSTEMS.each do |system|
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
	  field "description_#{system}".to_sym
	end
	
	index :systems_enabled
	index :codes
	index :name
	index :level
	index :active
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	index :updated_at
	
	references_many :carts, :validate => false
	references_many :orders, :validate => false, :index => true
	references_many :quotes, :validate => false, :index => true

	validates :name, :systems_enabled, :level, :presence => true
	validates_presence_of :codes, :unless => Proc.new {|obj| obj.no_code_required && obj.level == "shipping"}, :message => "can't be blank. Only shipping promotions can be setup with no_code_required option"
	validates_inclusion_of :level, :in => LEVELS, :message => "extension %s is not included in the list"
	validates_inclusion_of :discount_type, :in => DISCOUNT_TYPES, :message => "extension %s is not included in the list"
	validates_inclusion_of :discount_type, :in => ["percent"], :message => "must be 'percent' for order level coupons", :if => Proc.new {|obj| obj.order?}
	validates_inclusion_of :discount_type, :in => ["fixed", "percent"], :message => "must be 'fixed' or 'percent' for shipping coupons", :if => Proc.new {|obj| obj.level == "shipping" }
	validates_numericality_of :discount_value
	validates_exclusion_of :no_code_required, :in => [true], :unless => Proc.new {|obj| obj.level == "shipping"}, :message => "Only shipping promotions can be setup with no_code_required option"
	
	before_save Proc.new {|obj| obj.order_has_to_be.delete_if {|k,v| v.delete_if {|k,v| v.blank?}.blank?}}
	before_save :inherit_system_specific_attributes
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	scope :with_coupon, :where => { :no_code_required => false }
	scope :no_code_required, :where => { :no_code_required => true }	
  scope :by_location, lambda { |address| { :where => { :shipping_countries.in => [address.country]}.merge(address.us? ? {:shipping_states.in => [address.state]} : {})} }	
	
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
	  self.level == "shipping" || self.free_shipping
	end
	
	def buy_one_get_another?
	  self.buy_one_get_another == "buy_one_get_another"
	end
	
	def percent?
	  self.discount_type == "percent"
	end
	
	def absolute?
	  self.discount_type == "absolute"
	end
	
	def fixed?
	  self.discount_type == "fixed"
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
		write_attribute(:products, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
	end
	
	def product_excluded_item_nums
		read_attribute(:products_excluded).try :join, ", "
	end
	
	def product_excluded_item_nums=(product_item_nums)
		write_attribute(:products_excluded, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
	end
	
	def codes=(c)
	  write_attribute :codes, c.is_a?(Array) ? c : c.split(/,\s*/)
	end
	
private
  
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      %w(start_date end_date).each do |m|
        self.send("#{m}_#{sys}=", read_attribute("#{m}_#{current_system}")) if read_attribute("#{m}_#{sys}").blank?
      end      
    end
  end
end