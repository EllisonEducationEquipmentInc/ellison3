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
	field :country
	field :phone
	field :fax
	field :email
	
	embedded_in :user, :inverse_of => :addresses
	
	validates :address_type, :first_name, :last_name, :address1, :city, :zip_code, :phone, :presence => true
	
	def initialize(attributes = nil)
		super(attributes)
		self.country ||= "United States" if is_us?
		self.country ||= "United Kingdom" if is_uk?
	end
	
	def us?
		self.country == "United States"
	end
end
