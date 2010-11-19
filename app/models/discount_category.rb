# require 'retailer_discount_levels'

# TODO: admin for this
class DiscountCategory
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :name
	field :active, :type => Boolean, :default => true
	field :old_id, :type => Integer
	RetailerDiscountLevels.instance.levels.each do |level|
	  field :"discount_#{level.id}", :type => Integer
	  validates_presence_of :"discount_#{level.id}"
	  validates_numericality_of :"discount_#{level.id}", :only_integer => true
	end
	
	index :old_id
	
	references_many :products
	
	scope :active, :where => { :active => true }
	
  def discount(discount_level)
    send("discount_#{discount_level}")
  end
end
