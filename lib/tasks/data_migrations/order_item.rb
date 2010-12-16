module OldData
  class OrderItem < ActiveRecord::Base
    belongs_to :order
    belongs_to :product
    belongs_to :quote
    validates_presence_of :line_number 
  end
end