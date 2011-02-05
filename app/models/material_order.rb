class MaterialOrder
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Sequence
	
	field :order_number, :type=>Integer
  sequence :order_number
  	
	field :status
	field :shipped_at, :type => Date
	
	embeds_one :address
	referenced_in :user, :validate => false
	
	validates_presence_of :status, :address, :order_number
end
