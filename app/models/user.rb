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
	
	def initialize(attributes = nil)
		super(attributes)
		systems_enabled = [current_system]
	end

protected
   def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end
end
