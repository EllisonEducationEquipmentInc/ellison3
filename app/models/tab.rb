class Tab
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
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
	field :reusable, :type => Boolean, :default => false
	field :text
	field :products, :type => Array
	field :ideas, :type => Array
	field :compatibility, :type => Array
	field :data_column, :type => Hash
	
	# associations
	embedded_in :product, :inverse_of => :tabs
	embeds_many :images
	
	accepts_nested_attributes_for :images, :allow_destroy => true
	
	scope :active, :where => { :active => true }
	
	def available?
		active && systems_enabled.include?(current_system)
	end	
	
	def product_item_nums
		read_attribute(:products).try :join, ", "
	end
	
	def product_item_nums=(product_item_nums)
		write_attribute(:products, product_item_nums.split(/,\s?/)) unless product_item_nums.nil?
	end

	def compatibility_item_nums
		read_attribute(:compatibility) || []
	end
	
	def compatibility_item_nums=(compatibility_item_nums)
		write_attribute :compatibility, compatibility_item_nums.values.map {|c| c.split(/,\s?/)}
	end
end