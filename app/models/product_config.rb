class ProductConfig
  include EllisonSystem
  include Mongoid::Document
	include ActiveModel::Validations
	
	field :name
	field :description
	field :additional_name
	field :additional_description
	field :config_group
	field :display_order, :type => Integer
	field :icon
	
  embedded_in :product, :inverse_of => :product_config
end
