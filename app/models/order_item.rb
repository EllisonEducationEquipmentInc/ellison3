class OrderItem
	include EllisonSystem
	include Mongoid::Document
	
	field :item_num
	field :product_id
	field :name
	field :locale
	field :quoted_price, :type => Float
	field :sale_price, :type => Float
	field :discount, :type => Float
	field :custom_price, :type => Boolean, :default => false
	field :coupon_price, :type => Boolean, :default => false
	field :quantity, :type => Integer, :default => 1
	field :tax_exempt, :type => Boolean, :default => false
	# field :vat_exempt, :type => Boolean, :default => true
	field :upsell, :type => Boolean, :default => false
	field :outlet, :type => Boolean, :default => false
	
	embedded_in :order, :inverse_of => :order_items
	embedded_in :quote, :inverse_of => :order_items
	
	def item_total
		sale_price * quantity
	end
end