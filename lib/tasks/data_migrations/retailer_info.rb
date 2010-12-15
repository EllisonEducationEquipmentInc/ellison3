# encoding: utf-8
module OldData
  class RetailerInfo < ActiveRecord::Base
    validates_presence_of :signing_up_for, :first_name, :last_name, :job_title, :email, :address, :city, :zip, :country, :phone, :years_in_business, :number_of_employees, :annual_sales, :owner_president, :job_title, :home_address, :home_city, :home_zip, :home_country, :resale_number, :authorized_buyers, :business_type, :store_department, :store_location, :store_square_footage, :payment_method, :tax_id #, :resale_tax_certificate, :business_license, :store_photo
    validates_presence_of :state, :if => Proc.new { |obj| obj.country == "United States" }
    validates_presence_of :home_state, :if => Proc.new { |obj| obj.home_country == "United States" }
    validates_acceptance_of :terms, :accept => true, :message => "You must accept the terms of service."
    validates_acceptance_of :agree, :accept => true, :message => "You must read and agree to the Reseller Application Policy"
    validates_numericality_of :years_in_business, :number_of_employees
    validates_presence_of :website, :if => Proc.new {|p| !p.no_website}
    validates_format_of :website, :with => /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(([0-9]{1,5})?\/.*)?$/ix, :message =>"must be a valid url, ex: http://www.yoursite.com", :if => Proc.new {|p| !p.no_website}
  	validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i, :message => "address seems incorrect (check @ and . ‘s). Please enter your email address in the format user@domain.com."

    belongs_to :user
    belongs_to :resale_tax_certificate, :class_name => "Attachment", :foreign_key => "resale_tax_certificate_id", :validate => true
    belongs_to :business_license, :class_name => "Attachment", :foreign_key => "business_license_id", :validate => true
    belongs_to :store_photo, :class_name => "Attachment", :foreign_key => "store_photo_id", :validate => true

    BUSINESS_TYPES = ["Proprietorship", "Partnership", "Corporation", "Chain", "Other"]
    STORE_DEPARTMENTS = ["School Supplies", "Office Supplies", "District Buying Group", "Contract Stationer", "General Craft", "Scrapbooking/Stationary", "Rubberstamp", "Photo Specialty", "Quilting", "Other"]
    STORE_LOCATIONS = ["Shopping Center", "Downtown Business", "Outlying Business", "Residence", "Internet", "Catalog", "Other"]
    LEARNED_FROMS = ["Magazine/Advertising", "Tradeshow", "Salesperson/Representative", "Mailer", "Internet", "TV", "Other"]
    SQUARE_FOOTAGES = ["Less than 1,000 sq.ft.", "1,000-2,000 sq.ft", "2,001-3,000 sq.ft", "3,001-5,000 sq.ft", "5,001-10,000 sq.ft", "10,0001 and over"]

    def initialize(*args)
      super(*args)
      self.payment_method ||= "Credit Card"
      self.signing_up_for ||= "Wholesale"
    end

  end
  
end