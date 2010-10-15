class Cart
	include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :tax_amount, :type => Float
	field :tax_transaction
	field :tax_calculated_at, :type => DateTime
	field :shipping_rates, :type => Array
	field :shipping_service
	field :shipping_amount, :type => Float
	field :removed, :type => Integer, :default => 0
	field :changed_items, :type => Array
	
	referenced_in :coupon
	
	embeds_many :cart_items do
		def find_item(item_num)
			@target.detect {|item| item.item_num == item_num}
		end
	end
	
	def clear
		destroy
	end
	
	def reset_tax
		self.tax_amount, self.tax_transaction, self.tax_calculated_at = nil
	end
	
	def reset_shipping_amount
		self.shipping_amount, self.shipping_service, self.shipping_rates = nil
	end
	
	def reset_tax_and_shipping(to_save = false)
		reset_shipping_amount
		reset_tax
		save if to_save
	end
	
	def reset_item_errors
		update_attributes :removed => 0, :changed_items => nil
	end
	
	def sub_total
		cart_items.inject(0) {|sum, item| sum += item.total}
	end
	
	def total_weight
		cart_items.inject(0) {|sum, item| sum += (item.quantity * item.weight)}
	end
	
	def total_volume
		cart_items.inject(0) {|sum, item| sum += (item.quantity * item.volume)}
	end
	
	def taxable_amaunt
		cart_items.select {|i| !i.tax_exempt}.inject(0) {|sum, item| sum += item.total}
	end
	
	def handling_amount
		cart_items.inject(0) {|sum, item| sum += (item.quantity * item.handling_price)}
	end
	
	def total
		sub_total + tax_amount + shipping_amount + handling_amount
	end
	
	def changed_item_attributes
		self.changed_items.map {|e| e[1]}.flatten.uniq rescue nil
	end
	
	def cart_errors
		@cart_errors = []
		if !self.changed_items.blank? || self.removed > 0
			@cart_errors << "The price on one or more of the items in your order has been adjusted since you last placed it in your Shopping Cart. Items in your cart will always reflect the most recent price displayed on their corresponding product detail pages." if changed_item_attributes.include?("price")
			@cart_errors << "Some items placed in your cart are greater than the quantity available for sale. The most current quantity available has been updated in your Shopping Cart." if changed_item_attributes.include?("quantity")
			@cart_errors << "Some items placed in your Shopping Cart are no longer available for purchase and have been removed. If you are still interested in this item(s), please check back again at a later date for availability." if self.removed > 0
			@cart_errors << "The Handling price on one or more of the items in your order has been adjusted since you last placed it in your Shopping Cart." if changed_item_attributes.include?("handling_price")	
			# TODO: min qty, handling amount
			#"The quantity of some items placed in your cart is less than the required minimum quantity. The required minimum quantity has been updated in your Shopping Cart."
		end
		@cart_errors
	end
	
	def is_cart_item_changed?(cart_item_id, item_attribute)
		self.changed_items.detect {|i| i[0] == cart_item_id}[1].include? item_attribute
	rescue
		false
	end
		
	# to adjust qty and remove unavailable items and prompt user, pass true in the argument
	def update_items(check = false)
		return if cart_items.blank?
		Rails.logger.info "Cart: cart items are being updated"
		self.removed = 0
		self.changed_items = nil
		cart_items.each do |item|
			product = Product.find item.product_id
			item.write_attributes :sale_price => product.sale_price, :msrp => product.msrp, :currency => current_currency, :small_image => product.small_image, :tax_exempt => product.tax_exempt, :handling_price => product.handling_price
			item.price = product.price unless item.custom_price
			if check
				item.quantity = product.unavailable? ? 0 : product.quantity if product.unavailable? || product.quantity < item.quantity
			end
		end
		if check
			self.removed = cart_items.delete_all(:conditions => {:quantity.lt => 1}) 
			self.changed_items = cart_items.select(&:updated?).map {|i| [i.id, i.updated]}
		end
		reset_tax_and_shipping if cart_items.any?(&:updated?) || self.removed > 0
		save
	end
	
	
	# coupon discount applied here
	def apply_coupon_discount
	  cart_items.each {|i| i.write_attributes(:coupon_price => false)}
	  update_items
	  return if coupon.blank?
	  if coupon.product?
	    # check conditions
	    coupon.cart_must_have && coupon.cart_must_have.each do |key, product_items|
	      return unless product_items.send("#{key}?") {|i| item_nums.include?(i)}
	    end
	    cart_items.where(:item_num.in => coupon.products).each do |item|
	      item.write_attributes :coupon_price => true, :price => calculate_coupon_discount(item.price)
	    end
	  end
	  save
	end
	
	
	def calculate_coupon_discount(price)
	  return if coupon.blank?
	  if coupon.discount_type == "percent"
			price - (0.01 * coupon.discount_value * price).round(2)
		elsif coupon.discount_type == "absolute"
			price - coupon.discount_value
		elsif coupon.discount_type == "fixed"
			coupon.discount_value
		end
	end
end