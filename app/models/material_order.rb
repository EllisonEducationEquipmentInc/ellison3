class MaterialOrder
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Sequence
	
	STATUSES = ['NEW', 'IN PROCESS', 'SHIPPED', 'CANCELLED']
	
	field :order_number, :type=>Integer
  sequence :order_number
  	
	field :status, :default => 'NEW'
	field :shipped_at, :type => Date
	field :material_ids, :type => Array, :default => []
	field :material_label_codes, :type => Array, :default => []
	
	index :order_number
	index :status
	index :created_at
	index 'address.address1'
	index 'address.last_name'
	index 'address.company'
	
	embeds_one :address, :validate => false
	referenced_in :user, :validate => false
	#referenced_in :material, :validate => false
	
	validates_presence_of :status, :address, :order_number, :material_ids, :user_id
	validates_inclusion_of :status, :in => STATUSES, :message => "extension %s is not included in the list"
	accepts_nested_attributes_for :address
	
  def materials
    self.material_ids.present? ? Material.find(self.material_ids) : []
  end
end
