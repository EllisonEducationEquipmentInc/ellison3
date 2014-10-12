# cybersource authorization_reversal, recurring_billing extension
module ActiveMerchant #:nodoc:
  module Billing #:nodoc:

    # card validation overrides
    module CreditCardMethods
      CARD_COMPANIES['maestro'] = /(^(5[06-8]|6\d)\d{14}(\d{2,3})?$)|(^(5[06-8]|6\d)\d{10,17}$)|(^(5[0678])\d{11,18}$)|(^(6[^0357])\d{11,18}$)|(^(601)[^1]\d{9,16}$)|(^(6011)\d{9,11}$)|(^(6011)\d{13,16}$)|(^(65)\d{11,13}$)|(^(65)\d{15,18}$)|(^(633)[^34](\d{9,16}$))|(^(6333)[0-4](\d{8,10}$))|(^(6333)[0-4](\d{12}$))|(^(6333)[0-4](\d{15}$))|(^(6333)[5-9](\d{8,10}$))|(^(6333)[5-9](\d{12}$))|(^(6333)[5-9](\d{15}$))|(^(6334)[0-4](\d{8,10}$))|(^(6334)[0-4](\d{12}$))|(^(6334)[0-4](\d{15}$))|(^(67)[^(59)](\d{9,16}$))|(^[(6759)](\d{9,11}$))|(^[(6759)](\d{13}$))|(^[(6759)](\d{16}$))|(^(67)[^(67)](\d{9,16}$))|(^[(6767)](\d{9,11}$))|(^[(6767)](\d{13}$))|(^[(6767)](\d{16}$))/
      CARD_COMPANIES['solo'] = /^6767|6334\d{12}(\d{2,3})?$/
    end

    # don't validate solo/swith issue date
    class CreditCard
      private
      def validate_switch_or_solo_attributes
        # do nothing
      end
    end

    class CyberSourceGateway < Gateway

      attr_accessor :raw_xml

      def cc_code_to_cc(code)
        @@credit_card_codes.detect {|k,v| v == code}.first.to_s.humanize rescue ''
      end

      def authorization_reversal(money, request_id, request_token, options = {})
        commit(build_authorization_reversal_request(money, request_id, request_token, options), options)
      end

      # === Required options fileds (same as purchase, plus):
      #   :number_of_payments #=> integer
      #   :frequency #=> String, any of these: "on-demand", "weekly", "bi-weekly", "semi-monthly", "monthly", "quarterly", "quad-weekly", "semi-annually", "annually"
      #
      # === Optional options fields:
      #   :start_date #=> "%Y%m%d" default is 'today'
      #   :automatic_renew #=> Boolean, whether to automatically renew subscription after :number_of_payments are done. default is false
      # 
      #   To charge an initial setup fee, pass the amount (positive integer in cents) in :setup_fee option. It will create a 'purchase' transaction for the setup fee, and a subscription service at the same time
      #
      # === Example:
      #   Payment amount for the subscription is $12.99/month, setup fee is $89.99 one time fee. Number of payments ($12.99 payments) = 3, which start next month (20100620). credit_card is a valid ActiveMerchant::Billing::CreditCard object.  
      #
      #     Example: credit_card = ActiveMerchant::Billing::CreditCard.new(:first_name => Mark, :last_name => Ronai, :number => 4111111111111111, :month => 04, :year => 2013, :type => visa, :verification_value => 111)
      #     
      #     options = {:setup_fee=>8999, :shipping_address=>{}, :start_date=>"20100620", :order_id=>"order12345", :number_of_payments=>3, :email=>"name@example.com", :frequency=>"monthly", :billing_address=>{:state=>"CA", :city=>"Anytown", :zip=>"96666", :address1 => "123 Main st.", :country=>"United States", :company=>"ABC", :phone=>"1234567890"}}
      #     @gateway.recurring_billing(1299, credit_card, options)
      #
      # To tokenize (create and save) customer's billing info, send these option values: :number_of_payments=>0, :frequency=>"on-demand", :start_date => Time.zone.now, :setup_fee=> 0
      #   === Example:
      #     options = {:number_of_payments=>0, :email=>"name@example.com", :frequency=>"on-demand", :billing_address=>{:address1=>"123 Main st.", :country=>"United States", :company=>"ABC", :zip=>"96666", :phone=>"1234567890", :state=>"CA", :city=>"Anytown"}, :shipping_address=>{}, :start_date=> Time.zone.now.strftime("%Y%m%d"), :order_id=>"order123456", :subscription_title=>"subscriptiontitle", :setup_fee=>0, :customer_account_id=>"mark1235"}
      #     @gateway.recurring_billing(0, credit_card, options)
      def recurring_billing(money, creditcard, options = {})
        requires!(options, :order_id, :email, :number_of_payments, :frequency)
        setup_address_hash(options)
        commit(build_recurring_billing_request(money, creditcard, options), options)
      end

      def reversal(money, request_id, request_token, options = {})
        build_request(build_authorization_reversal_request(money, request_id, request_token, options), options)
      end

      def response(xml)
        ssl_post(test? ? TEST_URL : LIVE_URL, xml)
      end

      # retreive tokenized customer info
      # example: @gateway.retreive_customer_info :subscription_id=>"2774030660590008284282", :order_id=>"anything"
      def retreive_customer_info(options)
        requires!(options, :subscription_id, :order_id)
        commit(build_retreive_customer_info(options), options)
      end

      # update tokenized customer billing address, credit card (optional)
      # example: @gateway.update_customer_info {:email=>"changed@example.com", :billing_address=>{:address1=>"321 Main st.", :country=>"United States", :company=>"ABC", :zip=>"96666", :last_name=>"changed last", :phone=>"1234567890", :state=>"CA", :city=>"Anytown", :first_name=>"changedfirst"}, :shipping_address=>{}, :subscription_id=>"2774030660590008284282", :order_id=>"changed"}, credit_card
      def update_customer_info(options, creditcard = nil)
        requires!(options, :subscription_id, :order_id)
        setup_address_hash(options)
        commit(build_update_customer_info(options, creditcard), options)
      end

      def delete_customer_info(options)
        requires!(options, :subscription_id, :order_id)
        @raw_xml = build_request(build_delete_customer_info(options), options) 
        commit(build_delete_customer_info(options), options)
      end

      # charge payment on a previuosly saved customer credit card.
      # example: @gateway.pay_on_demand 6999, :order_id => "ondemand1234", :subscription_id => '2774030660590008284282'
      def pay_on_demand(money, options = {})
        requires!(options, :order_id, :subscription_id)
        @raw_xml = build_request(build_pay_on_demand_request(money, options), options) 
        commit(build_pay_on_demand_request(money, options), options)
      end

      def build_request(body, options)
        xml = Builder::XmlMarkup.new :indent => 2
          xml.instruct!
          xml.tag! 's:Envelope', {'xmlns:s' => 'http://schemas.xmlsoap.org/soap/envelope/'} do
            xml.tag! 's:Header' do
              xml.tag! 'wsse:Security', {'s:mustUnderstand' => '1', 'xmlns:wsse' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'} do
                xml.tag! 'wsse:UsernameToken' do
                  xml.tag! 'wsse:Username', @options[:login]
                  xml.tag! 'wsse:Password', @options[:password], 'Type' => 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText'
                end
              end
            end
            xml.tag! 's:Body', {'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema'} do
              xml.tag! 'requestMessage', {'xmlns' => 'urn:schemas-cybersource-com:transaction-data-1.53'} do
                add_merchant_data(xml, options)
                xml << body
              end
            end
          end
        xml.target! 
      end

    private

      def build_authorization_reversal_request(money, request_id, request_token, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_authorization_reversal_service(xml, request_id, request_token)
        xml.target!
      end

      def add_authorization_reversal_service(xml, request_id, request_token)
        xml.tag! 'ccAuthReversalService', {'run' => 'true'} do
          xml.tag! 'authRequestID', request_id
          xml.tag! 'authRequestToken', request_token
        end
      end

      def build_recurring_billing_request(money, creditcard, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_billing_address(xml, creditcard, options[:billing_address], options)
        add_purchase_data(xml, options[:setup_fee] || money, !options[:setup_fee].blank?, options)
        add_creditcard(xml, creditcard)
        add_subscription(xml, options) if options[:subscription_title]  
        add_recurring_subscription_info(xml, money, options)
        if options[:setup_fee]
          if options[:setup_fee] > 0
            #add_purchase_service(xml, options)
            add_auth_service(xml, options)
          else
            #add_auth_service(xml)
          end
        end
        add_recurring_billing_service(xml, options)
        xml.target!
      end

      def build_retreive_customer_info(options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_recurring_subscription_info(xml, nil, options)
        add_subscription_retreive_service(xml, options)
        xml.target!
      end

      def build_delete_customer_info(options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_recurring_subscription_info(xml, nil, options)
        add_subscription_delete_service(xml, options)
        xml.target!
      end

      def build_update_customer_info(options, creditcard = nil)
        xml = Builder::XmlMarkup.new :indent => 2
        add_billing_address(xml, creditcard, options[:billing_address], options)
        add_creditcard(xml, creditcard) if creditcard
        add_recurring_subscription_info(xml, nil, options)
        add_subscription_update_service(xml, options)
        xml.target!
      end

      def build_pay_on_demand_request(money, options)
        xml = Builder::XmlMarkup.new :indent => 2
        add_purchase_data(xml, money, true, options)
        add_recurring_subscription_info(xml, nil, options)
        #add_purchase_service(xml, options)
        add_auth_service(xml, options)
        xml.target!
      end

      def add_recurring_subscription_info(xml, money, options)
        xml.tag! 'recurringSubscriptionInfo' do
          xml.tag! 'subscriptionID', options[:subscription_id] if options[:subscription_id]
          xml.amount amount(money) if money
          xml.tag! 'numberOfPayments', options[:number_of_payments] if options[:number_of_payments]
          xml.tag! 'automaticRenew', options[:automatic_renew] || false if money
          xml.tag! 'frequency', options[:frequency] if options[:frequency]
          xml.tag! 'startDate', options[:start_date] || Time.zone.now.strftime("%Y%m%d") if money
        end
      end

      def add_subscription(xml, options)
        xml.tag! 'subscription' do
          xml.tag! 'title', options[:subscription_title]
        end
      end

      def add_subscription_update_service(xml, options)
        xml.tag! 'paySubscriptionUpdateService', {'run' => 'true'}
      end

      def add_recurring_billing_service(xml, options)
        xml.tag! 'paySubscriptionCreateService', {'run' => 'true'}
      end

      def add_subscription_retreive_service(xml, options)
        xml.tag! 'paySubscriptionRetrieveService', {'run' => 'true'}
      end

      def add_subscription_delete_service(xml, options)
        xml.tag! 'paySubscriptionDeleteService', {'run' => 'true'}
      end

      def add_billing_address(xml, creditcard, address, options)
        xml.tag! 'billTo' do
          xml.tag! 'firstName', address[:first_name] || creditcard.first_name
          xml.tag! 'lastName', address[:last_name] || creditcard.last_name 
          xml.tag! 'street1', address[:address1]
          xml.tag! 'street2', address[:address2]
          xml.tag! 'city', address[:city]
          xml.tag! 'state', address[:state]
          xml.tag! 'postalCode', address[:zip]
          xml.tag! 'country', address[:country]
          xml.tag! 'email', options[:email]
          xml.tag! 'customerID', options[:customer_account_id] if options[:customer_account_id]
        end 
      end

    end
  end
end
