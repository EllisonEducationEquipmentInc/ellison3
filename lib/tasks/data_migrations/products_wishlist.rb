module OldData
  class ProductsWishlist < ActiveRecord::Base
    belongs_to :product
    belongs_to :wishlist

    validates_presence_of :product_id

    def desired_price=(p)
      p.gsub!(/[^\d\.]/, "").to_f if p.class == String
      write_attribute(:desired_price, p)
    end
  end
end