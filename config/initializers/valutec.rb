require "savon"

class Valutec
  extend EllisonSystem
  CLIENT_KEY =  Rails.env == "production" ? '45bf3191-79e6-4883-818f-c93a35e98cc7' : '6986f09e-c288-4231-996a-5dfe3c2497d9'

  attr_accessor :action, :card_number, :amount, :response, :identifier, :request_auth_code

  def initialize(*args)
    @action = args.shift
    options = args.extract_options!
    @amount = options[:amount]
    @card_number = options[:card_number]
    @request_auth_code = options[:request_auth_code]
    @identifier = options[:identifier] || SecureRandom.hex(5)
    send @action
  end

  def client
    @client ||= Savon::Client.new("https://ws.valutec.net/Valutec.asmx?WSDL")
  end

  def soap_actions
    client.wsdl.soap_actions
  end

  def terminal_id
    Rails.env == "production" ? is_sizzix? ? '156028' : '156029' : '158348'
  end

  def method_missing(key, *args)
    if client.wsdl.soap_actions.include? key
      @response = client.request(key) do
        soap.body = {
          "ClientKey" => CLIENT_KEY,
          "TerminalID" => terminal_id,
          "ProgramType" => 'Gift',
          "CardNumber" => self.card_number,
          "Amount" => self.amount,
          "Identifier" => self.identifier
        }.merge(action == :transaction_void ? {"RequestAuthCode" => self.request_auth_code} : {})
      end
    else
      super
    end
  end
  
  def results
    @response.to_hash[:"#{@action}_response"][:"#{@action}_result"] if @response.success?
  end

  def balance
    results[:balance].to_f
  end

  def authorized?
    results[:authorized] rescue false
  end

  def card_num_last_four
    self.card_number.split("=").first[-4,4] rescue ''
  end

  def success?
    response && response.success?
  end

  def card_balance_was_not_used?
    action == :transaction_sale && authorized? && results[:card_amount_used] && results[:card_amount_used] == "0.00"
  end

  def card_amount_used
    if authorized? && action == :transaction_sale && results[:card_amount_used].nil? && results[:amount_due].nil?
      self.amount
    else
      results[:card_amount_used].to_f
    end
  end

  def errors
    unless authorized?
      {
        "CARD NOT ACTIVE" => "The Gift Card number you entered is not active. Please contact Customer Service.",
        "CARD NOT FOUND" => "The Gift Card number you entered is not valid. Please check the number and try again.",
        "CARD DEACTIVATED" => "The Gift Card number you entered is not active. Please <a href='/contact'>contact</a> Customer Service.",
        "CANNOT ACCEPT CARD" => "The Pin number you entered is not valid. Please check the number and try again."
      }[results[:error_msg]] || results[:error_msg]
    end.html_safe
  end

end

