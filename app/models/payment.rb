class Payment
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	attr_accessor :full_card_number, :card_issue_year, :card_issue_month, :card_issue_number, :use_previous_orders_card

	field :first_name
	field :last_name
	field :company
	field :address1
	field :address2
	field :city
	field :state
	field :zip_code
	field :country
	field :phone
	field :email
	
	field :payment_method, :default => "Credit Card"
	field :card_name
	field :card_number
	field :card_expiration_month
	field :card_expiration_year
	field :card_security_code
	
	field :use_saved_credit_card, :type => Boolean, :default => false
	field :deferred, :type => Boolean, :default => false
	
	field :cv2_result
	field :status
	field :vpstx_id
	field :security_key
	field :tx_auth_no
	field :status_detail
	field :address_result
	field :post_code_result
	field :subscriptionid
	field :paid_amount, :type => BigDecimal
	field :authorization
	field :paid_at, :type => DateTime
	field :vendor_tx_code
	
	embedded_in :order, :inverse_of => :payment
	
	validates_presence_of :email
	
	def self.cards
    is_us? ? %w(Visa MasterCard Discover AmericanExpress) : [["Visa", "visa"],["MasterCard", "master"],["Visa Debit", "delta"], ["Solo", "solo"],["Maestro", "maestro"], ["Visa Electron (UKE)", "electron"]]
  end

  def self.months
    months = []
    Date::MONTHNAMES.each_index {|i| months << ["#{Date::MONTHNAMES[i]} (#{i})",i] unless i == 0}
    months
  end
  
  def self.years
    start_year = Date.today.year
    years = []
    11.times do
      years << start_year
      start_year += 1
    end
    years
  end
  
  def self.issue_years
    start_year = Date.today.year - 4
    years = []
    5.times do
      years << start_year
      start_year += 1
    end
    years
  end
end