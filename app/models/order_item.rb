class OrderItem
	include EllisonSystem
	include Mongoid::Document
	
	field :item_num
	field :name
	field :locale
	field :quoted_price, :type => Float
	field :sale_price, :type => Float
	field :discount, :type => Float
	field :custom_price, :type => Boolean, :default => false
	field :coupon_price, :type => Boolean, :default => false
	field :quantity, :type => Integer, :default => 1
	field :tax_exempt, :type => Boolean, :default => false
	field :vat_exempt, :type => Boolean, :default => false
	field :vat, :type => Float
	field :vat_percentage, :type => Float
	field :upsell, :type => Boolean, :default => false
	field :outlet, :type => Boolean, :default => false
	
	embedded_in :order, :inverse_of => :order_items
	embedded_in :quote, :inverse_of => :order_items
	referenced_in :product
	
	def gross_price
	  sale_price + vat
	rescue
	  sale_price
	end
	
	def item_total
		gross_price * quantity
	end
end