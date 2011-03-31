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
  
  validates_presence_of :email
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i
  validates_uniqueness_of :email, :scope => :list, :message => "address has already been subscribed."
 
  before_save :set_list
  

private

	def set_list
		self.list ||= subscription_list
	end

end