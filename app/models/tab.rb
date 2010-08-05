class Tab
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	# include Mongoid::Versioning
	# include Mongoid::Timestamps
	# include Mongoid::Paranoia
		
	# validations
	validates :name, :systems_enabled, :systems_enabled, :presence => true
	
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
	
	# associations
	embedded_in :product, :inverse_of => :tabs
	
	def available?
		active && systems_enabled.include?(current_system)
	end	
end