module OldData
  class BillingAddress < ActiveRecord::Base

    validates_presence_of :first_name, :last_name, :email, :address, :city, :zip_code, :country, :phone, :message => " of Billing Address can't be blank "
    validates_presence_of :company, :message => "of Billing Address can't be blank ", :if => Proc.new {|p| p.is_er?}
    validates_presence_of :state, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :first_name, :in => 2..255
    validates_length_of :last_name, :in => 2..255
    #validates_length_of :email, :in => 7..255
    validates_length_of :address, :in => 2..255
    validates_length_of :city, :in => 2..255 
    validates_length_of :phone, :is => 10, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :phone, :in => 5..20, :if => Proc.new{|p| p.country != "United States"}
    validates_length_of :state, :in => 2..255, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :country, :in => 2..255
    validates_numericality_of :phone, :if => Proc.new{|p| p.country == "United States"}
    validates_format_of :zip_code, :with => /^(\d{5})(-\d{4})?$/i, :if => proc { |p| p.country == "United States" }
    #validates_format_of :zip_code, :with => /(?:[A-Z]{1,2}\d(?:\d|[A-Z])? \d[A-Z]{2})$/i,  :message => "is not a British Standard (BS 7666) Postal Code", :if => proc { |obj| obj.country == "United Kingdom" }
                                      #[A-Z]{1,2}[0-9R][0-9A-Z]? [0-9][A-Z]{2}

    serialize :tokenized_info, Hash

    belongs_to :user

    def validate_on_update
      if read_attribute('country') == "United States"
        if !Zipcode.valid_address?(read_attribute('city'),
                                   read_attribute('state'),
                                   read_attribute('zip_code'))
          # we'll only report on one of the fields to reduce confusion
          #errors.add(:city, "- city/state/zip combination invalid") 
        end
      end
    end

    #<BillingAddress id: 56, first_name: "Mark", last_name: "Ronai", password: nil, address: "25862 Commercentre Drive", address2: "", city: "lake Forest", state: "CA", country: "United States", postcode: nil, email: "mronai@ellison.com", phone: "9493232322", fax: nil, created_at: "2009-02-03 13:07:00", updated_at: "2010-06-28 17:20:58", street_address: nil, zip_code: "92630", shipping_method: nil, user_id: 35, credit_card: nil, card_number: nil, expiration_month: nil, expiration_year: nil, card_verification_number: nil, company: "comp inc", invoice_account: "oewldf", subscriptionid: "2777456601160008284310", tokenized_info: nil, tokenized_info_date: nil>
    #=> {"customerAccountID"=>"mark1235", "firstNme"=>"MARK", "country"=>"US", "title"=>"subscriptiontitle", "street1"=>"123 Main st.", "subscriptionID"=>"2774176050310008284282", "automaticRenew"=>"false", "startDate"=>"20100624", "postalCode"=>"96666", "totalPayments"=>"0", "merchantReferenceCode"=>"aweweweqq", "cardExpirationMonth"=>"10", "currency"=>"USD", "frequency"=>"on-demand", "decision"=>"ACCEPT", "reasonCode"=>"100", "status"=>"CURRENT", "endDate"=>"99991231", "paymentMethod"=>"credit card", "email"=>"name@example.com", "cardType"=>"001", "cardAccountNumber"=>"411111XXXXXX1111", "state"=>"CA", "cardExpirationYear"=>"2012"}

    def populate_tokenized_info
      return if tokenized_info.blank?
      self.first_name = tokenized_info['firstName']
      self.last_name = tokenized_info['lastName']
      self.address = tokenized_info['street1']
      self.address2 = tokenized_info['street2']
      self.city = tokenized_info['city']
      self.state = tokenized_info['state']
      self.zip_code = tokenized_info['postalCode']
      self.country = tokenized_info['country'] == 'US' ? "United States" : tokenized_info['country']
      self.email = tokenized_info['email']
      self
    end

    def validate
      if country == "United Kingdom"
        errors.add(:post_code, "is not a British Standard (BS 7666) Post Code") unless zip_code =~ /(?:[A-Z]{1,2}\d(?:\d|[A-Z])? \d[A-Z]{2})$/i
      end
    end

  end
  
end