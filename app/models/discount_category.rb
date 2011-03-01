# require 'retailer_discount_levels'

class DiscountCategory
  include EllisonSystem
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
	validates_presence_of :name
	
	cache
	
	index :old_id
	
	references_many :products, :validate => false, :index => true
	
	scope :active, :where => { :active => true }
	
  def discount(discount_level)
    send("discount_#{discount_level}")
  end
  
  def destroy
    update_attribute :active, false
  end
end
