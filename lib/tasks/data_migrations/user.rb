# encoding: utf-8
module OldData
  class User < ActiveRecord::Base

    require 'digest/sha1'

    #after_save :flush_cache

    ROLES = [ 'customer', 'content_admin', 'customer_admin', 'administrator', 'sales_rep', 'sales_manager', 'artist', 'limited_sales_rep']

    STATES = [['active',     'unsuspend'], 
              ['suspended',  'suspend'],
              ['deleted',    'delete']]
    EVENTS = [['Activate', 'activate'], ['Suspend', 'suspend'], ['Delete', 'deleted'], ['Unsuspend','unsuspend']]

    attr_protected :role

    # Virtual attribute for the unencrypted password
    attr_accessor :password
    #attr_accessor :old_password
    attr_accessor :identity_url
    attr_accessor :password_confirmation

    #validates_confirmation_of :password_confirmation 
    named_scope :not_deleted, :conditions => ["state != ?", "deleted"]
    named_scope :customer_only, :conditions => ["role = ?", ROLES[0]]
    named_scope :not_customers, :conditions => ["role != ?", ROLES[0]]

    has_and_belongs_to_many :roles
    has_and_belongs_to_many :catalogs
    has_and_belongs_to_many :idea_catalogs

    has_many :user_openids, :dependent => :destroy

    belongs_to :artist
    has_many :customers
    has_many :billing_addresses
    has_many :orders
    belongs_to :account
    belongs_to :discount_level
    validates_associated :account, :message => " - Please fill out all required fields."
    has_many :quotes
    has_many :material_orders
    has_one :retailer_info
    has_many :wishlists

    validates_presence_of :artist_id, :if => Proc.new {|p| p.role == 'artist'}
    validates_presence_of     :email,                       :if => :not_openid?
    validates_presence_of :name, :if => Proc.new(&:is_er?)
    validates_presence_of :first_name, :last_name, :if => Proc.new(&:is_ee?)
    validates_length_of       :email,    :within => 3..50, :if => :not_openid?
    #validates_presence_of     :login
    #validates_length_of       :login,    :within => 3..100
    #validates_uniqueness_of   :login,    :case_sensitive => false, :message => 'is already taken; sorry!'
    validates_uniqueness_of   :email,    :case_sensitive => false, :message => '%s already exists; do you already have an account?'
    validates_presence_of     :password,                    :if => :password_required?, :message => "can't be blank. Please enter a new password."
    validates_presence_of     :password_confirmation,       :if => :password_required?, :message => "can't be blank. Please enter a password confirmation."
    validates_length_of       :password, :within => 5..15,  :if => :password_required?, :too_short => "entered is too short.  Please enter a password between 8 and 15 characters.", :too_long => "entered is too long.  Please enter a password between 5 and 15 characters."
    validates_confirmation_of :password,                    :if => :password_required?, :message => "and your password confirmation did not match."
    validates_format_of :password, :with => /((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{8,15})/i, :if => :password_required?, :message => "must contain at least one letter and one digit, length must be between 8 and 15 characters"
    validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "address seems incorrect (check @ and . ‘s). Please enter your email address in the format user@domain.com."
                                          #/^([a-z0-9_]+)(\.?)([a-z0-9_]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
    validates_numericality_of :first_order_minimum, :order_minimum, :allow_nil => true, :if => Proc.new(&:is_er?)

    before_save :encrypt_password
    before_create :make_activation_code
    after_create :make_user_openid

    # custom attribute names in error messages
    HUMANIZED_ATTRIBUTES = {
       :email => "E-mail address"
    }
    def self.human_attribute_name(attr)
      HUMANIZED_ATTRIBUTES[attr.to_sym] || super
    end

  	def get_default_wishlist(id = nil)
  		unless id.blank?
  			wishlists.active.find(id)
  		else
  			wishlists.active.default.first || wishlists.active.first || wishlists.build(:name => "Untitled List", :default => true)
  		end
  	end

    # acts_as_state_machine :initial => ENV['system'] ==  "ellison_retailers" ? :pending : :active
    # state :passive
    # state :pending, :enter => :make_activation_code
    # state :active,  :enter => :do_activate
    # state :suspended
    # state :deleted, :enter => :do_delete
    # state :declined
    # 
    # event :register do
    #   transitions :from => :passive, :to => :pending, :guard => Proc.new {|u| !(u.crypted_password.blank? && u.password.blank?) }
    # end
    # 
    # event :activate do
    #   transitions :from => :pending, :to => :active 
    # end
    # 
    # event :suspend do
    #   transitions :from => [:passive, :pending, :active], :to => :suspended
    # end
    # 
    # event :delete do
    #   transitions :from => [:passive, :pending, :active, :suspended], :to => :deleted
    # end
    # 
    # event :unsuspend do
    #   transitions :from => :suspended, :to => :active,  :guard => Proc.new {|u| !u.activated_at.blank? }
    #   transitions :from => :suspended, :to => :pending, :guard => Proc.new {|u| !u.activation_code.blank? }
    #   transitions :from => :suspended, :to => :passive
    # end
    # 
    # event :decline do
    #   transitions :from => :pending, :to => :declined 
    # end

    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    def self.authenticate(login, password)
      #u = find_in_state :first, :active, :conditions => {:login => login, :deleted => false, :state => 'active'} # need to get the salt
      u = self.find(:first, :conditions => ["login = ? AND deleted = ? AND state IN (?)", login, false, ['active', 'pending']])
      if u && u.authenticated?(password)
        u.update_last_login
        return u 
      else  
        return nil
      end  
    end

    def tax_exempt
      is_er? ? true : account.try(:tax_exempt)
    end

    def tax_exempt_certificate
  		if is_ee?
  			account.try :tax_exempt_number
  		elsif is_er?
  			retailer_info.try :resale_number
  		end
    end

  	alias :tax_exempt_number :tax_exempt_certificate

    # has valid assigned erp_id? (AX id)
    def erp_id?
      !erp_id.blank? && erp_id.downcase != 'new'
    end

    def update_last_login
      update_attribute(:last_login, Time.zone.now)
    end

    # Encrypts some data with the salt.
    def self.encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    end

    def self.customers
      find :all, :conditions => ['role = ?', "customer"]
    end

    def self.find_by_identity_url(openid_url)
      user_openid = UserOpenid.find_by_openid_url(openid_url, :include => :user)
      user_openid.nil? ? nil : user_openid.user
    end

    def self.find_for_forget(login)  
      find :first, :conditions => ['login = ? and activation_code is null', login]  
    end
    # Encrypts the password with the user salt
    def encrypt(password)
      self.class.encrypt(password, salt)
    end

    def authenticated?(password)
      crypted_password == encrypt(password)
    end

    def remember_token?
      remember_token_expires_at && Time.zone.now.utc < remember_token_expires_at 
    end

    # These create and unset the fields required for remembering users between browser closes
    def remember_me
      remember_me_for 2.weeks
    end

    def remember_me_for(time)
      remember_me_until time.from_now.utc
    end

    def remember_me_until(time)
      self.remember_token_expires_at = time
      self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
      save(false)
    end

    def forget_me
      self.remember_token_expires_at = nil
      self.remember_token            = nil
      save(false)
    end

    def check_auth(pw)  
      if User.authenticate(self.login, pw)
        @change_pw = true      
      else  
        errors.add(:old_password, "does not equal current password.")  
        @change_pw = false  
      end  
    end  

    def forgot_password  
      @forgot_pw = true  
      self.make_password_reset_code  
      self.save  
    end  

    def reset_password(pw, confirm)  
      @reset_pw = true  
      update_attributes(:password => pw, :password_confirmation => confirm, :first_time_login => false)  
    end      

    def uk_reset_password(pw, confirm,newsletter)  
      @reset_pw = true  
      update_attributes(:password => pw, :password_confirmation => confirm, :customer_newsletter => newsletter, :first_time_login => false)  
    end

    def has_role?(name)  
      self.role.eql?(name) ? true : false  
    end

    def change_state(state)
      self.method("#{state}!").call
    end

    def normal_account?
      return true if self.not_openid?
    end

    def openid_account?
      return true if !self.not_openid?
    end

    def forgot_pw?  
      @forgot_pw  
    end  

    def reset_pw?  
      @reset_pw  
    end  

    def change_pw?  
      @change_pw  
    end
    protected
    # before filter 
    def encrypt_password
      return if password.blank?
      self.salt = Digest::SHA1.hexdigest("--#{Time.zone.now.to_s}--#{login}--") if new_record? || self.salt.blank?
      self.crypted_password = encrypt(password)
    end

    def password_required?
      not_openid? && (crypted_password.blank? || !password.blank?) || @change_pw || @reset_pw
    end

    def not_openid?
      identity_url.blank? && user_openids.count == 0
    end

    def make_activation_code
      logger.info("*@*@*@*@*@*@* user.make_activation_code")
      self.activation_code = Digest::SHA1.hexdigest( Time.zone.now.to_s.split(//).sort_by {rand}.join )
    end

    def make_password_reset_code
      logger.info("*@*@*@*@*@*@* user.make_password_reset_code")
      self.reset_password_code = Digest::SHA1.hexdigest( Time.zone.now.to_s.split(//).sort_by {rand}.join )
      self.reset_password_expires_at = 3.day.from_now
    end

    def make_user_openid
      self.user_openids.create(:openid_url => identity_url) unless identity_url.blank?
    end

    def do_delete
      self.deleted_at = Time.zone.now.utc
    end

    def do_activate
      logger.info("*&*&*&*&* user.do_activate")
      self.activated_at = Time.zone.now.utc
      self.deleted_at = self.activation_code = nil
    end

    def validate_on_update
      errors.add(:erp_id, "Please update the User's Axapta ID (ERP id) before activating the user.") if is_er? && active? && erp_id == "New"
    end
  end
  
end