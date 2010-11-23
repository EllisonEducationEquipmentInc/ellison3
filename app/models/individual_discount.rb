class IndividualDiscount
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	
	validates :discount, :discount_type, :presence => true
	validates_numericality_of :discount, :greater_than => 0.0
		
	field :product_id
	field :label
	field :item_num
	field :discount, :type => Float
	field :discount_type, :type => Integer, :default => 0
	field :msrp, :type => Float
	
	embedded_in :campaign, :inverse_of => :individual_discounts
	
	after_destroy :remove_from_product
	
	def price
	  return if self.msrp.blank?
		if discount_type == 0
			msrp - (0.01 * discount * msrp).round(2)
		elsif discount_type == 1
		  msrp - discount > 0 ? msrp - discount : 0.0
		elsif discount_type == 2
			discount
		end
	end
	
private
  
  def remove_from_product
    product = Product.find(self.product_id)
    product.campaigns.find(campaign.id).delete
    product.save(:validate => false)
  rescue
  end
end