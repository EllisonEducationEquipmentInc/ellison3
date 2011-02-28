class Admin
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :trackable, :validatable, :timeoutable, :lockable
	
	ROLES = ["admin", "content_admin", "customer_admin", "sales_rep", "limited_sales_rep"]
	
	accepts_nested_attributes_for :permissions, :allow_destroy => true
	
	field :name
	field :employee_number
	field :active, :type => Boolean, :default => false
	field :can_act_as_customer, :type => Boolean, :default => false
	field :can_change_prices, :type => Boolean, :default => false
	field :systems_enabled, :type => Array
	
	index :email
	index :name
	index :employee_number
	index :sign_in_count
	index :created_at
	index :failed_attempts
	index :current_sign_in_at
	index :updated_at
	
	embeds_many :permissions do
	  
	  def read_access_to(admin_module, sys = current_system)
	    @target.detect {|permission| permission.name == admin_module && permission.systems_enabled.include?(sys) && permission.read}
	  end
	  
	  def write_access_to(admin_module, sys = current_system)
	    @target.detect {|permission| permission.name == admin_module && permission.systems_enabled.include?(sys) && permission.write}
	  end
	end
	
	validates_presence_of :name, :employee_number
	validates_uniqueness_of :name, :email, :employee_number, :case_sensitive => false
	validates_format_of :password,	:if => :password_required?, :with => /((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15})/i, :message => "must contain at least one letter and one digit, length must be between 8 and 15 characters"
	
	attr_accessible :name, :email, :password, :password_confirmation, :employee_number
	
	def initialize(attributes = nil)
		super(attributes)
		self.systems_enabled ||= [current_system]
	end
	
	def self.find_for_authentication(conditions={})
    conditions[:active] = true
		conditions[:systems_enabled.in] = [current_system] 
    super
  end
  
  def has_read_access?(admin_module, sys = current_system)
    !permissions.read_access_to(admin_module, sys).blank?
  end
  
  def has_write_access?(admin_module, sys = current_system)
    !permissions.write_access_to(admin_module, sys).blank?
  end
  
  def destroy
    update_attribute :active, false
  end

protected
  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end
end