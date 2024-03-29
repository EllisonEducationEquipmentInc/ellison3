class Admin
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :trackable, :validatable, :timeoutable, :lockable, :encryptable

  ROLES = ["admin", "content_admin", "customer_admin", "sales_rep", "limited_sales_rep"]

  accepts_nested_attributes_for :permissions, :allow_destroy => true, :reject_if => proc { |attributes| attributes['read'] == "0" && attributes['write'] == "0" && attributes['systems_enabled'].blank?}

  field :name
  field :employee_number
  field :active, :type => Boolean, :default => false
  field :can_act_as_customer, :type => Boolean, :default => false
  field :limited_sales_rep, :type => Boolean, :default => false
  field :can_change_prices, :type => Boolean, :default => false
  field :systems_enabled, :type => Array
  field :reset_password_token_expires_at, :type => DateTime
  field :reset_password_sent_at, :type => DateTime

  field :reset_password_token
  field :email
  field :encrypted_password,  type: String, null: false, default: ""
  field :role

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Lockable
  field :failed_attempts, :type => Integer # Only if lock strategy is :failed_attempts
  field :unlock_token,    :type => String # Only if unlock strategy is :email or :both
  field :locked_at,       :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  field :created_by
  field :updated_by

  index :email
  index :name
  index :employee_number
  index :sign_in_count
  index :created_at
  index :failed_attempts
  index :current_sign_in_at
  index :updated_at

  references_many :users, :validate => false, :index => true

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
  validates_format_of :password,  :if => :password_required?, :with => /((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15})/i, :message => "must contain at least one letter and one digit, length must be between 8 and 15 characters"

  attr_accessible :name, :email, :password, :password_confirmation, :employee_number

  scope :sales_reps, :where => { :active => true,  :can_act_as_customer => true}

  class << self
    def reset_password_by_token(attributes={})
      recoverable = where(:reset_password_token_expires_at.gt => Time.now).find_or_initialize_with_error_by(:reset_password_token, attributes[:reset_password_token], "is invalid or expired. Please request a new one.")
      recoverable.reset_password!(attributes[:password], attributes[:password_confirmation]) unless recoverable.new_record?
      recoverable
    end

    def send_reset_password_instructions(attributes={})
      recoverable = find_or_initialize_with_error_by(:email, attributes[:email], :not_found)
      recoverable.send_reset_password_instructions if recoverable.persisted? && recoverable.active
      recoverable.errors.add(:email, :not_found) unless recoverable.active
      recoverable
    end
  end

  def initialize(attributes = nil)
    super
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

  def reset_password!(new_password, new_password_confirmation)
    if new_password.blank?
      errors.add(:password, "cannot be blank")
    else
      self.password = new_password
      self.password_confirmation = new_password_confirmation
      clear_reset_password_token if valid?
      save
    end
  end

  protected
  def password_required?
    !persisted? || password.present? || password_confirmation.present?
  end

  # Generates a new random token for reset password
  def generate_reset_password_token
    self.reset_password_token = self.class.reset_password_token
    self.reset_password_token_expires_at = 3.days.since
  end

  # Resets the reset password token with and save the record without
  # validating
  def generate_reset_password_token!
    generate_reset_password_token && save(:validate => false)
  end

  # Removes reset_password token
  def clear_reset_password_token
    self.reset_password_token = nil
    self.reset_password_token_expires_at = nil
  end
end
