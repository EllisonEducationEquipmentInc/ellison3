class Cart
	include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	#field :coupon
	embeds_many :cart_items do
		def find_item(item_num)
			@target.detect {|item| item.item_num == item_num}
		end
	end
	
	def clear
		destroy
	end
	
	def sub_total
		cart_items.inject(0) {|sum, item| sum += item.total}
	end
	
	def total_weight
		cart_items.inject(0) {|sum, item| sum += item.weight}
	end
end