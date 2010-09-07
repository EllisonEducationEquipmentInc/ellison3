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
		
		def get_gateway(system = nil)
      unless system
        system = if is_sizzix_us?
                   'sizzix_us'
                 elsif is_ee_us? 
                   'ee_us'
                 elsif is_er? 
                   'er'
                 else
                   'uk'
                 end
      end
      options = if system == 'sizzix_us'
                {:merchant_account => {
                   :name => 'cyber_source',
                   :user_name => 'sizzix',
                   :password => 'gjSlJTQJGbiPL5fAwVZ2ho0r98LmsYw1FOdGq675dIZzsASmsv5/M2kKhc3mwAtPGlVBAf12UVToDRYqcXpQJUtkXCvp1oDQ0RyqmQlTH9CGUGh3lR+7jVwJ5+8qokWtWnrYuUU3JDE4suev4jYGCQ9lutmXAmhH5+OpxGG84TRsV7APDoSoJM4UhtGpYnaGjSv3wuaxjDUU50arrvl0hnOwBKay/n8zaQqFzebAC08aVUEB/XZRVOgNFipxelAlS2RcK+nWgNDRHKqZCVMf0IZQaHeVH7uNXAnn7yqiRa1aeti5RTckMTiy56/iNgYJD2W62ZcCaEfn46nEYbzhNA==',
                   :login => 'sizzix'}}
              elsif system == 'ee_us'
                 {:merchant_account => {
                   :name => 'cyber_source',
                   :user_name => 'ellison',
                   :password => 'wpc4lHdGRv/Q8rXAmLy9bNdrZr2tTZdU5SypZVRb4Q2hapwjIIiYszLzcrQZG6R1fh+76JKLhlqIjeoY/Hzvfh2OD+/GQzUznEhn7HOk4rPWiLHQogY7ZpCCQNhEt2SCaeMjHrpg2ugpPvriX2MT7hPt8L2XeRddpYdIFUSL2Y/iLhCFg3CDVmQ4gUcYZ1Ns12tmva1Nl1TlLKllVFvhDaFqnCMgiJizMvNytBkbpHV+H7vokouGWoiN6hj8fO9+HY4P78ZDNTOcSGfsc6Tis9aIsdCiBjtmkIJA2ES3ZIJp4yMeumDa6Ck++uJfYxPuE+3wvZd5F12lh0gVRIvZjw==',
                   :login => 'ellison'}}
             elsif system == 'er'
                {:merchant_account => {
                  :name => 'cyber_source',
                  :user_name => 'ellisonretail',
                  :password => 'skoRfHH6Z9g5muYxQYau+F3xx6VpMvBgIiaYF7ehVa6Fi+oMmU2mG+naCHaPQvJ7maLAV+Fv8DHwUjvB755DujWNmRm0JK257S//v8Amf+coDwzBukjQIw3rwKmTribTW9swVYFeTNSzIe7PkHzkJdqVzSr6MyL1b1E5CditD6FSbqpYS9EwS+SDAfReWVUub1jHpWky8GAiJpgXt6FVroWL6gyZTaYb6doIdo9C8nuZosBX4W/wMfBSO8HvnkO6NY2ZGbQkrbntL/+/wCZ/5ygPDMG6SNAjDevAqZOuJtNb2zBVgV5M1LMh7s+QfOQl2pXNKvozIvVvUTkJ2K0PoQ==',
                  :login => 'ellisonretail'}}
              else
                 {:merchant_account => {
                   :name => 'protx',
                   :user_name => 'ellison',
                   :password => 'ellisond',
                   :login => 'ellisonadmin'}}
               end
      config = Config.new(options)
      ActiveMerchant::Billing::Base.mode = :test unless RAILS_ENV == 'production' 
      @gateway = ActiveMerchant::Billing::Base.gateway(config.name.to_s).new(:login => config.user_name.to_s, :password => config.password.to_s)    
    rescue
      raise 'Invalid ActiveMerchant Gateway'
    end

	end
	
	def self.included(receiver)
		receiver.extend         ClassMethods
		receiver.send :include, InstanceMethods
	end
end