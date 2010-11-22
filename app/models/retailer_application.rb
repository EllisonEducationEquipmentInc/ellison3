class RetailerApplication
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	
	attr_accessor :agreed_to_policy, :agreed_to_terms

  AVAILABLE_BRANDS = %w(Sizzix Ellison AllStar)
  SIGN_UP_FOR = %w(Wholesale Distributor)
  PAYMENT_METHODS = ["Credit Card", "Prepaid"]
  BUSINESS_TYPES = ["Proprietorship", "Partnership", "Corporation", "Chain", "Other"]
  STORE_DEPARTMENTS = ["School Supplies", "Office Supplies", "District Buying Group", "Contract Stationer", "General Craft", "Scrapbooking/Stationary", "Rubberstamp", "Photo Specialty", "Quilting", "Other"]
  STORE_LOCATIONS = ["Shopping Center", "Downtown Business", "Outlying Business", "Residence", "Internet", "Catalog", "Other"]
  LEARNED_FROMS = ["Magazine/Advertising", "Tradeshow", "Salesperson/Representative", "Mailer", "Internet", "TV", "Other"]
  SQUARE_FOOTAGES = ["Less than 1,000 sq.ft.", "1,000-2,000 sq.ft", "2,001-3,000 sq.ft", "3,001-5,000 sq.ft", "5,001-10,000 sq.ft", "10,0001 and over"]
  
  field :signing_up_for, :default => SIGN_UP_FOR.first
  field :website
  field :no_website, :type => Boolean, :default => false
  field :tax_identifier
  field :years_in_business, :type => Integer
  field :number_of_employees, :type => Integer
  field :annual_sales
  field :resale_number
  field :brands_to_resell, :type => Array, :default => []
  field :authorized_buyers
  field :business_type
  field :store_department
  field :store_location
  field :how_did_you_learn_about_us
  field :store_square_footage
  field :payment_method, :default => PAYMENT_METHODS.first
  field :will_fax_documents, :type => Boolean, :default => false
  
  validates :signing_up_for, :tax_identifier, :years_in_business, :number_of_employees, :number_of_employees, :annual_sales, :resale_number, :authorized_buyers, :brands_to_resell, :business_type, :store_department, :store_location, :payment_method, :presence => true
	validates_presence_of :resale_tax_certificate, :business_license, :store_photo, :unless => Proc.new {|obj| obj.will_fax_documents}
  validates_format_of :website, :with => /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix, :message =>"must be a valid url, ex: http://www.yoursite.com", :if => Proc.new {|p| !p.no_website}
  validates_presence_of :website, :if => Proc.new {|p| !p.no_website}
	validates_numericality_of :years_in_business, :number_of_employees
	
	validates_acceptance_of :agreed_to_policy, :message => "You must read and agree to the Reseller Application Policy."
	validates_acceptance_of :agreed_to_terms, :message => "Reseller Terms and Conditions of Trading."
	
	embedded_in :user, :inverse_of => :retailer_application

  mount_uploader :resale_tax_certificate, PrivateAttachmentUploader
  mount_uploader :business_license, PrivateAttachmentUploader
  mount_uploader :store_photo, PrivateAttachmentUploader

end
