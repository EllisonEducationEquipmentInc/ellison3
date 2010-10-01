class User
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable

	field :name
	field :systems_enabled, :type => Array
	field :tax_exempt, :type => Boolean, :default => false
	field :tax_exempt_certificate
	validates_uniqueness_of :email, :case_sensitive => false
	attr_accessible :name, :email, :password, :password_confirmation

	references_many :orders, :index => true
	
	index :email
	index :systems_enabled
	
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
		self.systems_enabled = [current_system]
	end
	
	def billing_address
		addresses.billing.last
	end
	
	def shipping_address
		addresses.shipping.last
	end
	
  def self.find_for_authentication(conditions={})
    #conditions[:active] = true
		conditions[:systems_enabled.in] = [current_system] 
    super
  end

protected
	def password_required?
	  !persisted? || password.present? || password_confirmation.present?
	end
end
