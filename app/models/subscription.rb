class Subscription
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  attr_protected :email, :list, :confirmed, :verification_sent
  
  field :email
  field :list
  field :list_name
  field :segments, :type => Array, :default => []
  field :name
  field :confirmed, :type => Boolean, :default => false
  field :unsubscribe, :type => Boolean, :default => false
  field :verification_sent, :type => DateTime
  
  validates_presence_of :email, :list_name
  validates_format_of :email, :with => /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}$/i
  validates_uniqueness_of :email, :scope => :list, :message => "address has already been subscribed.", :case_sensitive => false
  
  scope :confirmed, :where => { :confirmed => true }
 
  before_save :set_list
  
  index :email
  index :list
  index :confirmed
  
private

	def set_list
		self.list ||= subscription_list
	end

end
