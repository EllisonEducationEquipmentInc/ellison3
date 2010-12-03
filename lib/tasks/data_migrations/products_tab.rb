module OldData
  class ProductsTab < ActiveRecord::Base
    belongs_to :product
    belongs_to :tab
  end
end