module ShoppingCart
	module ClassMethods
		
	end
	
	module InstanceMethods
		def get_cart
      @cart ||= (Cart.find(session[:shopping_cart]) rescue Cart.new)
    end
		
		def add_2_cart(product, qty = 1)
			if item = get_cart.cart_items.find_item(product.item_num)
				item.quantity += qty
			else
				get_cart.cart_items << CartItem.new(:name => product.name, :item_num => product.item_num, :sale_price => product.sale_price, :msrp => product.msrp, :price => product.price, :quantity => qty, :currency => current_currency, :small_image => product.small_image, :added_at => Time.now, :product_id => product.id)
			end
			get_cart.save
			session[:shopping_cart] ||= get_cart.id.to_s
		end
		
		def remove_cart(item_num)
			cart_item = get_cart.cart_items.find_item(item_num)
			cart_item.delete
			get_cart.save
			cart_item.id.to_s
		end
		
		def clear_cart
			get_cart.clear
			session[:shopping_cart], @cart = nil
		end


	end
	
	def self.included(receiver)
		receiver.extend         ClassMethods
		receiver.send :include, InstanceMethods
	end
end