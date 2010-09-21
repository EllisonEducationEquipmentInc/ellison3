class Admin
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :trackable, :validatable, :timeoutable, :lockable
	
	field :name
	field :employee_number
	field :active, :type => Boolean, :default => false
	field :systems_enabled, :type => Array
	
	validates_presence_of :name, :employee_number
	validates_uniqueness_of :name, :email, :employee_number, :case_sensitive => false
	validates_format_of :password,	:if => :password_required?, :with => /((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15})/i, :message => "must contain at least one letter and one digit, length must be between 8 and 15 characters"
	
	attr_accessible :name, :email, :password, :password_confirmation, :employee_number, :active
	
	def self.find_for_authentication(conditions={})
    conditions[:active] = true
		conditions[:systems_enabled.in] = [current_system] 
    super
  end

protected
  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end
end