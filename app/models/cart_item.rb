class CartItem
	include EllisonSystem
	include Mongoid::Document
	
	field :item_num
	field :product_id
	field :name
	field :msrp, :type => BigDecimal
	field :sale_price, :type => BigDecimal
	field :price, :type => BigDecimal
	field :currency
	field :quantity, :type => Integer, :default => 1
	field :small_image
	field :added_at, :type => Time
	
	embedded_in :cart, :inverse_of => :cart_items
	
	def total
		price * quantity
	end
end