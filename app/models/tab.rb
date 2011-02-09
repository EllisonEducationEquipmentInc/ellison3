class Tab
	include EllisonSystem
	include Mongoid::Document
	# include Mongoid::Versioning
	# include Mongoid::Timestamps
	# include Mongoid::Paranoia
				
	# validations
	validates :name, :systems_enabled, :presence => true
	
	# field definitions
	field :name
	field :description
	field :active, :type => Boolean, :default => true
	field :systems_enabled, :type => Array
	#field :reusable, :type => Boolean, :default => false
	field :text
	field :products, :type => Array
	field :ideas, :type => Array
	field :compatibility, :type => Array
	field :data_column, :type => Array
	field :display_order, :type => Integer
	
	# associations
	embedded_in :product, :inverse_of => :tabs
	embedded_in :idea, :inverse_of => :tabs
	embeds_many :images
	
	referenced_in :shared_content
	
	accepts_nested_attributes_for :images, :allow_destroy => true
	
	scope :active, :where => { :active => true }
	
	def display_order
		read_attribute(:display_order) || self._index
	end
	
	def available?
		active && systems_enabled.include?(current_system)
	end	
	
	def product_item_nums
		read_attribute(:products).try :join, ", "
	end
	
	def product_item_nums=(product_item_nums)
		write_attribute(:products, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
	end
	
	def idea_item_nums
		read_attribute(:ideas).try :join, ", "
	end
	
	def idea_item_nums=(idea_item_nums)
		write_attribute(:ideas, idea_item_nums.split(/,\s*/)) unless idea_item_nums.nil?
	end

	def compatibility_item_nums
		read_attribute(:compatibility) || []
	end
	
	def compatibility_item_nums=(compatibility_item_nums)
		write_attribute :compatibility, compatibility_item_nums.values.map {|c| c.split(/,\s*/)}
	end
	
	def data_column_fields
		read_attribute(:data_column) || []
	end
	
	def data_column_fields=(data_column_fields)
		write_attribute :data_column, data_column_fields.sort {|a, b| a[0].to_i <=> b[0].to_i}.map {|a| a[1].values}
	end
	
	def no_image_details?
	  self.images && images.all? {|e| e.details.blank?}
	end
	
	def shared_content_id=(scid)
	  write_attribute :shared_content_id, scid if scid.valid_bson_object_id?
	end

end