class Feedback
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	
	STATUSES = %w(new replied ignored closed)
	DEPARTMENTS = ["Customer Service", "Marketing", "Sales", "R&D", "I.T"]
	
	def self.statuses
	  if is_er?
  	  ['Corporate Information', 'General Suggestion', 'Retailer Information Request', 'Retailer Stores Update', 'Miscellaneous']
  	elsif is_ee_us?
  	  ['Order or Payment', 'Return or Exchange', 'Fundraising', 'Workshops', 'International Support', 'Retailer Support', 'Other']
    elsif is_ee_uk?
      ['General Enquiry', 'Product Enquiry', 'Order Delivery', 'Change Order', 'Order Returns', 'Website Feedback']
    elsif is_sizzix_uk?
      ['General Enquiry', 'Product Enquiry', 'eclips Enquiry', 'Order Delivery', 'Change Order', 'Order Returns', 'Website Feedback']
  	else
  	  ['Order or Payment', 'Return or Exchange', 'International Consumer', 'Retailer Inquiry','eclips','Custom Dies','Other']
  	end
	end
	
	field :email
	field :subject
	field :expires_at, :type => DateTime
	field :priority, :type => Integer, :default => 0
	field :status, :default => 'new'
	field :department
	
	attr_protected :status, :priority
	
	validates_presence_of :email, :subject, :expires_at, :status
	validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
	validates_inclusion_of :status, :in => STATUSES
	validates_associated :comments, :message => "can't be blank"
	
	referenced_in :user
	embeds_many :comments
	
	accepts_nested_attributes_for :comments, :allow_destroy => true
	
end
