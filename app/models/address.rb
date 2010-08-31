class Address
	include EllisonSystem
  include Mongoid::Document
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	field :address_type, :default => "shipping"
	field :default, :type => Boolean
	field :first_name
	field :last_name
	field :company
	field :address1
	field :address2
	field :city
	field :state
	field :zip_code
	field :country, :default => "United States"
	field :phone
	field :fax
	field :email
	
	embedded_in :user, :inverse_of => :addresses
end
