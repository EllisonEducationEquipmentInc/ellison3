class MaterialOrder
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Sequence
	
	field :order_number, :type=>Integer
  sequence :order_number
  	
	field :status, :default => 'NEW'
	field :shipped_at, :type => Date
	field :material_ids, :type => Array, :default => []
	
	embeds_one :address, :validate => false
	referenced_in :user, :validate => false
	#referenced_in :material, :validate => false
	
	validates_presence_of :status, :address, :order_number, :material_ids, :user_id
	accepts_nested_attributes_for :address
	
  def materials
    self.material_ids.present? ? Material.find(self.material_ids) : []
  end
end
