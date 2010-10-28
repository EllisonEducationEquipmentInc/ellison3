class CartItem
	include EllisonSystem
	include Mongoid::Document
	
	field :item_num
	field :product_id
	field :name
	field :msrp, :type => Float
	field :sale_price, :type => Float
	field :price, :type => Float
	field :custom_price, :type => Boolean, :default => false
	field :coupon_price, :type => Boolean, :default => false
	field :currency
	field :quantity, :type => Integer, :default => 1
	field :small_image
	field :added_at, :type => Time
	field :weight, :type => Float, :default => 0.0
	field :volume, :type => Float, :default => 0.0
	field :tax_exempt, :type => Boolean, :default => false
	field :handling_price, :type => Float, :default => 0.0
	field :changed_attributes, :type => Array
	field :pre_order, :type => Boolean, :default => false
	field :out_of_stock, :type => Boolean, :default => false
	
	embedded_in :cart, :inverse_of => :cart_items
	
	before_save {|item| item.changed_attributes = item.updated}
	
	def total
		price * quantity
	end
	
	# Whether *price*, *quantity*,  *handling_price* have changed so checkout process should halt and cart has to be updated - but not due to currency change
	def updated?
		changed? && !changed.include?("currency") && changed.any? {|a| sensitive_attributes.include?(a)}
	end
	
	# sensitive attributes that have changed
	def updated
		changed.select {|a| sensitive_attributes.include?(a)}
	end
	
	# collection of attributes whose change should trigger cart update and halt the checkout process
	def sensitive_attributes
		%w(price quantity handling_price)
	end
	
	# if line item is a coupon
	def coupon?
	  self.item_num == Coupon::COUPON_ITEM_NUM
	end
end