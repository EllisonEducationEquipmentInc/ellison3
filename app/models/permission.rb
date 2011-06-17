class Permission
  include EllisonSystem
	include Mongoid::Document
	
	ADMIN_MODULES = ["products", "ideas", "tags", "landing_pages", "static_pages", "shared_contents", "profiles", "users", "orders", "quotes", "coupons", "countries", 
	  "us_shipping_rates", "shipping_rates", "feedbacks", "stores", "events", "compatibilities", "virtual_terminal", "materials", "material_orders", "firmwares", 
	  "messages", "discount_categories", "search_phrases", "navigations", "reports", "system_settings"]
		
	validates :name, :systems_enabled, :presence => true
	
	field :name
	field :systems_enabled, :type => Array
	field :read, :type => Boolean, :default => true
	field :write, :type => Boolean, :default => false
	
	embedded_in :admin, :inverse_of => :permissions
	
	def write=(w)
	  write_attribute :write, w
	  self.read = true if self.write
	end
	
end