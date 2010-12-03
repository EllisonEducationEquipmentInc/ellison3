module OldData
  class Price < ActiveRecord::Base
    belongs_to :product #, :touch => true

    validates_presence_of :msrp, :regular_price
    validates_numericality_of :msrp, :regular_price, :greater_than => 0
  end
end