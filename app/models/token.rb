class Token
  include EllisonSystem
  include Mongoid::Document
	include ActiveModel::Validations
	include ActiveModel::Translation
		
	validates :subscriptionid, :presence => true
	
	field :subscriptionid
	field :card_name
	field :card_number
	field :card_expiration_month
	field :card_expiration_year
	field :status
	field :first_name
	field :last_name
	field :address1
	field :address2
	field :city
	field :state
	field :zip_code
	field :country
	field :email
	field :last_updated, :type => DateTime
	
	embedded_in :user, :inverse_of => :token
	
	def current?
	  self.last_updated && self.last_updated > Time.zone.now.beginning_of_day && self.status == "CURRENT"
	end
end