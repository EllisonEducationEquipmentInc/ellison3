class User
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
	field :erp
	field :purchase_order, :type => Boolean, :default => false
	field :discount_level, :type => Integer
	field :status, :default => "pending"
	
	validates_uniqueness_of :email, :case_sensitive => false
	validates_presence_of :tax_exempt_certificate, :if => Proc.new {|obj| obj.tax_exempt}
		
	attr_accessible :name, :company, :email, :password, :password_confirmation, :addresses_attributes
	
	accepts_nested_attributes_for :addresses
	
	validates_associated :retailer_application, :addresses

	references_many :orders, :index => true
	references_many :quotes, :index => true
	references_many :lists, :index => true do
	  def owns
			@target.detect {|list| list.owns}
    end
    
    def default
			@target.detect {|list| list.default_list}
    end
	end
	
	index :email
	index :systems_enabled
	index :sign_in_count
	index :created_at
	index :status
	
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
    l = List.new :owns => true, :name => "Products I own", :comments => "List of products I already own. The list is automatically generated from your order history."
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
  
  def list_set_to_default(list_id)
    raise "list #{list_id} not found." unless lists.all.detect {|e| e.id.to_s == list_id}
    lists.all.each {|e| e.update_attributes :default_list => e.id.to_s == list_id}
  end
  
  def build_default_mylist
    lists.build(:name => "Untitled List", :default_list => true)
  end
  
  def tax_exempt?
    self.tax_exempt || is_er? && self.systems_enabled.include?("er")
  end
  
  def application_complete?
    !retailer_application.blank? && !billing_address.blank? && !shipping_address.blank? && !retailer_application.blank?
  end

  def build_addresses(*address_types)
    address_types.each do |address_type|
      addresses.build(:address_type => address_type, :email => self.email) unless send("#{address_type}_address")
    end
  end

protected
	def password_required?
	  !persisted? || password.present? || password_confirmation.present?
	end
end
