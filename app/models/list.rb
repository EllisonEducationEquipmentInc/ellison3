class List
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	
	referenced_in :user
	
	validates :name, :user_id, :presence => true
	
	field :name
	field :active, :type => Boolean, :default => true
	field :default_list, :type => Boolean, :default => false
	field :owns, :type => Boolean, :default => false
	field :save_for_later, :type => Boolean, :default => false
	field :product_ids, :type => Array, :default => []
	field :comments
	field :old_permalink
	
	scope :listable, :where => { :active => true,  :save_for_later.ne => true}
	
	def products
	  Product.displayable.where(:_id.in => self.product_ids).cache
	end
	
	def add_product(product_id)
	  product_id = BSON::ObjectId(product_id) if product_id.is_a?(String)
	  unless self.product_ids.include?(product_id)
	    self.product_ids << product_id 
	    save
	  end
	end
	
	def destroy
    update_attribute :active, false
  end
end