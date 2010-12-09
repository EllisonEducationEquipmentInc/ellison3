module OldData
  require 'base64'

  class Payment < ActiveRecord::Base

    validates_presence_of :card_name, :payment_type, :if => Proc.new {|p| p.purchase_order.blank?}
    has_one :order
    belongs_to :purchase_order_document, :class_name => "Attachment", :foreign_key => "purchase_order_document_id", :validate => true
    #before_save :encrypt_card_number, :if => Proc.new {|p| p.purchase_order.blank?}
    #after_save :decrypt_card_number, :if => Proc.new {|p| p.purchase_order.blank?}
    before_save :mask_card_number, :clear_cvv, :if => Proc.new {|p| p.purchase_order.blank?}

    attr_accessor :full_card_number, :card_expiration_month, :card_expiration_year, :card_issue_year, :card_issue_month, :card_issue_number, :use_previous_orders_card

    # deferred payment constants
  	NUMBER_OF_PAYMENTS = 2 	# not including first time 'setup' fee
  	FREQUENCY = 'monthly'

    def match_attr
      write_attribute('address', read_attribute('address1')) 
      write_attribute('zip_code', read_attribute('zip'))
    end

    def use_again
      record = self.class.new
      #decrypt_card_number
      [:card_name, :card_number, :card_expiration_month, :card_expiration_year, :card_issue_year, :card_issue_month, :card_issue_number, :card_security_code, :payment_type, :purchase_order, :purchase_order_document_id, :subscriptionid].each {|a| record.send("#{a}=", send(a))}    
      #record.decrypt_card_number unless record.card_number =~ /^\d{13,16}$/
      record
    end

    def full_card_number=(n)
      write_attribute :card_number, mask_number(n.dup)
      @full_card_number = n
    end

    def card_expiration_month
      @card_expiration_month || card_expiration.strftime("%m") rescue nil
    end

    def card_expiration_year
      @card_expiration_year || card_expiration.strftime("%Y") rescue nil
    end

    def mask_card_number
      masked = read_attribute('card_number').dup
      0.upto(masked.size - 5) { |i| masked[i] = 'x'}
      write_attribute :card_number, masked
      @mask_card_number = masked
    end

    def self.cards
      %w(Visa MasterCard Discover AmericanExpress)
    end

    def self.uk_cards
      [["Visa", "visa"],["MasterCard", "master"],["Visa Debit", "delta"], ["Solo", "solo"],["Maestro", "maestro"], ["Visa Electron (UKE)", "electron"]]
    end

    def self.months
      months = []
      Date::MONTHNAMES.each_index {|i| months << [Date::MONTHNAMES[i],i] unless i == 0}
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

    # Use this key for AES
    #@@key = EzCrypto::Key.with_password('Go Rails!', 'axapta')

    # Use this key for custom encryption
    @@key = "ellisonwebcreditcardkey"

    # AES methods

    #def decrypt_card_number
      #value = read_attribute('card_number')
      #write_attribute('card_number', @@key.decrypt64(value)) if value
    #end

    #def encrypt_card_number
      #value = read_attribute('card_number')
      #write_attribute('card_number', @@key.encrypt64(value)) if value
    #end

    # custom encryption methods

    def decrypt_card_number
      value = read_attribute('card_number')

      if value
        i = 0
        unmasked = ""

        decoded = Base64.decode64(value)
        decoded.each_byte do |b|
          if i < @@key.length
            unmasked << b - @@key[i]
          else
            unmasked << b
          end
          i += 1
        end
        write_attribute('card_number', Base64.decode64(unmasked))
      end
    end

    def encrypt_card_number
      value = read_attribute('card_number')

      if value
        i = 0
        masked = ""

        encoded = Base64.encode64(value)
        encoded.each_byte do |b|
          if i < @@key.length
            masked << b + @@key[i]
          else
            masked << b
          end
          i += 1
        end
        write_attribute('card_number', Base64.encode64(masked))
      end
    end

    # end custom encryption

    def validate
      # unless validate_card(read_attribute('card_number'))
      #   errors.add(:number, "- Credit card number entered is invalid.")
      # end
    end

  private

  	def clear_cvv
  		write_attribute :card_security_code, nil
  	end

    def mask_number(n)
      0.upto(n.size - 5) { |i| n[i] = 'x'}
      n
    end

    def validate_card(number)
      #http://en.wikipedia.org/wiki/Luhn_algorithm
      return true if !purchase_order.blank?
      return true if number == "4111111111111111"
      sum = 0
      for i in 0..number.length
        weight = number[-1 * (i + 2), 1].to_i * (2 - (i % 2))
        sum += (weight < 10) ? weight : weight - 9
      end

      (number[-1,1].to_i == (10 - sum % 10) % 10)
    end

    def valid_for_mod10?(card_number)
      digits = card_number.to_s.split('').map { |d| d.to_i }
      new_digits = []

      reversed = digits.reverse
      reversed.each_index do |i|
        if i % 2 > 0
          num = 2 * reversed[i]
          if num >= 10
            num_digits = num.to_s.split('').map { |d| d.to_i }
            new_digits << num_digits.inject(0) { |sum, d| sum + d }
          else
            new_digits << num
          end
        else
          new_digits << reversed[i]
        end
      end

      total = new_digits.reverse.inject(0) { |sum, d| sum + d }
      if total % 10 == 0
        return true
      else
        return false
      end
    end
  end
  
end