require 'carrierwave/orm/mongoid'

class Payment
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	
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
	
	field :save_credit_card, :type => Boolean, :default => false
	field :use_saved_credit_card, :type => Boolean, :default => false
	field :deferred, :type => Boolean, :default => false
	field :purchase_order, :type => Boolean, :default => false
	field :purchase_order_number
	
	field :cv2_result
	field :status
	field :vpstx_id
	field :security_key
	field :tx_auth_no
	field :status_detail
	field :address_result
	field :post_code_result
	field :subscriptionid
	field :paid_amount, :type => Float
	field :authorization
	field :paid_at, :type => DateTime
	field :vendor_tx_code
	
	field :void_at, :type => DateTime
  field :void_amount, :type => Float
  field :void_authorization
  
  field :refunded_at, :type => DateTime
  field :refunded_amount, :type => Float
  field :refund_authorization
  
  field :deferred_payment_amount, :type => Float
  field :number_of_payments, :type => Integer
  field :frequency
	
	mount_uploader :attachment, PrivateAttachmentUploader	
	
	embedded_in :order, :inverse_of => :payment
	
	validates_presence_of :email
	validates_presence_of :purchase_order_number, :if => Proc.new {|obj| obj.purchase_order}
	
	before_save :mask_card_number
	
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
  
  def mask_card_number
    return if self.full_card_number.blank?
    masked = self.full_card_number.dup
    0.upto(masked.size - 5) { |i| masked[i] = 'x'}
    write_attribute :card_number, masked
  end
end