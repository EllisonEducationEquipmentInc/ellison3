class Account
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	
	references_many :users, :index => true
	
	field :active, :type => Boolean, :default => true
	field :school
  field :name
  field :city
  field :erp
  field :address1
  field :address2
  field :zip_code
  field :title
  field :country
  field :avocation, :type => Integer, :default => 0
  field :students, :type => Integer, :default => 0
  field :individual, :type => Boolean
  field :institution
  field :resale_number
  field :phone
  field :fax
  field :description
  field :affiliation
  field :tax_exempt_number
  field :tax_exempt, :type => Boolean, :default => false
  field :state
  field :email
  field :old_id, :type => Integer
  
  index :old_id
end
