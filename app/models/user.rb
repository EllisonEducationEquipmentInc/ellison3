class User
  include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
  # Include default devise modules. Others available are:
  # :token_authenticatable, :confirmable, :lockable and :timeoutable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable, :validatable
  
  STATUSES = ["pending", "active", "suspended", "declined"]

	field :name
	field :company
	field :systems_enabled, :type => Array
	field :tax_exempt, :type => Boolean, :default => false
	field :tax_exempt_certificate
	field :invoice_account
	field :erp, :default => 'New'
	field :purchase_order, :type => Boolean, :default => false
	field :discount_level, :type => Integer
	field :status, :default => "pending"
	field :first_order_minimum, :type => Integer
	field :order_minimum, :type => Integer
	field :customer_newsletter, :type => Boolean, :default => false
	field :outlet_newsletter, :type => Boolean, :default => false
	field :real_deal, :type => Boolean, :default => false
	field :default_user, :type => Boolean, :default => false
	field :internal_comments
	field :machines_owned, :type => Array
	field :cod_account_type
	field :cod_account
	
	field :old_account_id, :type => Integer
	field :old_id_szus, :type => Integer
	field :old_id_szuk, :type => Integer
	field :old_id_eeus, :type => Integer
	field :old_id_eeuk, :type => Integer
	field :old_id_er, :type => Integer
	field :old_password_hash
	field :old_salt
	field :old_user, :type => Boolean, :default => false
	
	field :created_by
	field :updated_by
	
	validates_uniqueness_of :email, :case_sensitive => false, :if => Proc.new {|obj| obj.new_record? || obj.email_changed?}
	validates_presence_of :tax_exempt_certificate, :if => Proc.new {|obj| obj.tax_exempt}
	validates_numericality_of :order_minimum, :first_order_minimum, :allow_nil => true, :only_integer => true
	validates_format_of :password,	:if => :password_required?, :with => /((?=.*\d)(?=.*[a-z])(?=.*[A-Z]).{6,15})/i, :message => "must contain at least one letter and one digit, length must be between 6 and 15 characters"
	
	attr_accessible :name, :company, :email, :password, :password_confirmation, :addresses_attributes
	
	accepts_nested_attributes_for :addresses
	
	validates_associated :retailer_application, :addresses

  referenced_in :account
  referenced_in :admin, :validate => false
  
  references_many :feedbacks, :validate => false, :index => true
	references_many :orders, :validate => false, :index => true
	references_many :material_orders, :validate => false, :index => true
	references_many :quotes, :validate => false, :index => true
	references_many :messages, :validate => false, :index => true
	references_many :lists, :index => true do
	  def owns
			@target.detect {|list| list.owns}
    end
    
    def save_for_later
			@target.detect {|list| list.save_for_later}
    end
    
    def default
			@target.detect {|list| list.default_list}
    end
	end
	
	index :email
	index :erp
	index :name
	index :systems_enabled
	index :sign_in_count
	index :created_at
	index :status
	index :old_user
	index :old_id_szus
	index :old_id_eeus
	index :old_id_szuk
	index :old_id_eeuk
	index :old_id_er
	
	embeds_one :token
	embeds_one :retailer_application
	embeds_many :addresses do
    def billing
			@target.select {|address| address.address_type == "billing"}
    end

		def shipping
			@target.select {|address| address.address_type == "shipping"}
    end
    
    def home
			@target.select {|address| address.address_type == "home"}
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
	
	def home_address
		addresses.home.last
	end
	
  def self.find_for_authentication(conditions={})
    conditions[:status.nin] = ["suspended", "declined"]
		conditions[:systems_enabled.in] = [current_system] 
    super
  end
  
  def create_owns_list
    return unless lists.owns.blank?
    l = List.new :owns => true, :name => "Items I own", :comments => "List of items I already own. The list is automatically generated from your order history."
    l.product_ids = orders.only(:status, "order_items.product_id").where(:status.in => ["Open", "Processing", "In Process", "Shipped"]).inject([]) {|all,e| all += e.order_items.map {|i| i.product_id}}.compact.uniq
    l.user = self
    l.save
  end
  
  def add_to_owns_list(product_ids)
    create_owns_list
    l = lists.owns
    l.product_ids = (l.product_ids + product_ids).compact.uniq
    l.save
  end
  
  def create_save_for_later_list
    return unless lists.save_for_later.blank?
    l = List.new :save_for_later => true, :name => "Saved Items - To Buy Later", :comments => "List of products I saved to purchase later"
    l.user = self
    l.save
  end
  
  def add_to_save_for_later_list(product_ids)
    create_save_for_later_list
    l = lists.save_for_later
    l.product_ids = (l.product_ids + product_ids).compact.uniq
    l.save
  end
  
  def save_for_later_list
    create_save_for_later_list
    lists.save_for_later
  end
  
  def list_set_to_default(list_id)
    raise "list #{list_id} not found." unless lists.all.detect {|e| e.id.to_s == list_id}
    lists.all.each {|e| e.update_attributes :default_list => e.id.to_s == list_id}
  end
  
  def build_default_mylist
    lists.build(:name => "Untitled List", :default_list => true)
  end
  
  def tax_exempt?
    !is_sizzix? && self.tax_exempt || is_er? && self.systems_enabled.include?("erus")
  end
  
  def application_complete?
    !retailer_application.blank? && !billing_address.blank? && !shipping_address.blank? && !retailer_application.blank?
  end

  def build_addresses(*address_types)
    address_types.each do |address_type|
      addresses.build(:address_type => address_type, :email => self.email) unless send("#{address_type}_address")
    end
  end
  
  def self.old_encrypt(password, salt)
    Digest::SHA1.hexdigest("--#{salt}--#{password}--")
  end
  
  def old_authenticated?(password)
    old_password_hash == self.class.old_encrypt(password, self.old_salt)
  end
  
  def cod_account_info
    return if self.cod_account_type.blank? || self.cod_account.blank?
    shipping_service = Shippinglogic::FedEx::Rate::Service.new
    shipping_service.name = shipping_service.type = "COD"
    shipping_service.rate = 0.0
    shipping_service
  end

protected
	def password_required?
	  !persisted? || password.present? || password_confirmation.present?
	end
end
