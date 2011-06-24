class CartItem
	include EllisonSystem
	include Mongoid::Document
	
	field :item_num
	field :name
	field :msrp, :type => Float                                 # product.msrp_or_wholesale_price
	field :sale_price, :type => Float
	field :price, :type => Float
	field :retailer_price, :type => Float
	field :custom_price, :type => Boolean, :default => false
	field :coupon_price, :type => Boolean, :default => false
	field :campaign_name
	field :coupon_name
	field :currency
	field :quantity, :type => Integer, :default => 1
	field :minimum_quantity, :type => Integer, :default => 1
	field :small_image
	field :added_at, :type => Time
	field :weight, :type => Float, :default => 0.0
	field :actual_weight, :type => Float, :default => 0.0
	field :volume, :type => Float, :default => 0.0
	field :tax_exempt, :type => Boolean, :default => false
	field :handling_price, :type => Float, :default => 0.0
	field :changed_attributes, :type => Array
	field :pre_order, :type => Boolean, :default => false
	field :out_of_stock, :type => Boolean, :default => false
	field :upsell, :type => Boolean, :default => false
	
	embedded_in :cart, :inverse_of => :cart_items
	referenced_in :product
	
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
		%w(price quantity handling_price out_of_stock)
	end
	
	# if line item is a coupon
	def coupon?
	  self.item_num == Coupon::COUPON_ITEM_NUM
	end
	
	def eclips?
		item_num == "655934" || item_num == "29184" || (item_num == "654427" && Rails.env == 'development')
	end
	
	def calculate_coupon_discount(coupon)
	  return if coupon.blank?
	  p = if coupon.percent?
			self.msrp - (0.01 * coupon.discount_value * self.msrp).round(2)
		elsif coupon.absolute?
			self.msrp - coupon.discount_value > 0 ? self.msrp - coupon.discount_value : 0.0
		elsif coupon.fixed?
			coupon.discount_value
		end
		write_attributes :coupon_price => true, :coupon_name => coupon.name, :price => p if p < self.price
	end
end