class User
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

	field :name
	field :systems_enabled, :type => Array
	validates_uniqueness_of :email, :case_sensitive => false
	attr_accessible :name, :email, :password, :password_confirmation

	references_many :orders
	
	embeds_many :addresses do
    def billing
			@target.select {|address| address.address_type == "billing"}
    end

		def shipping
			@target.select {|address| address.address_type == "shipping"}
    end
  end

	def initialize(attributes = nil)
		super(attributes)
		systems_enabled = [current_system]
	end
	
	def billing_address
		addresses.billing.last
	end
	
	def shipping_address
		addresses.shipping.last
	end

protected
	def password_required?
	  !persisted? || password.present? || password_confirmation.present?
	end
end
