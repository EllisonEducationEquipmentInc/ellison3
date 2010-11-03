class List
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	referenced_in :user
	
	field :name
	field :active, :type => Boolean, :default => true
	field :default_list, :type => Boolean, :default => false
	field :owns, :type => Boolean, :default => false
	field :product_ids, :type => Array, :default => []
	
	def products
	  Product.send(current_system).available.where(:_id.in => self.product_ids).cache
	end
end