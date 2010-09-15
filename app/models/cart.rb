class Cart
	include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :tax_amount, :type => Float
	field :tax_transaction
	field :tax_calculated_at, :type => DateTime
	field :shipping_amount, :type => Float
	
	#field :coupon
	
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
		self.shipping_amount = nil
	end
	
	def reset_tax_and_shipping(to_save = false)
		reset_shipping_amount
		reset_tax
		save if to_save
	end
	
	def sub_total
		cart_items.inject(0) {|sum, item| sum += item.total}
	end
	
	def total_weight
		cart_items.inject(0) {|sum, item| sum += item.weight}
	end
	
	def taxable_amaunt
		cart_items.select {|i| !i.tax_exempt}.inject(0) {|sum, item| sum += item.total}
	end
	
	def total
		sub_total + tax_amount + shipping_amount
	end
end