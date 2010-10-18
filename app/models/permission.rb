class Permission
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	
	ADMIN_MODULES = ["products", "tags", "landing_pages", "profiles", "users", "orders", "coupons"]
		
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