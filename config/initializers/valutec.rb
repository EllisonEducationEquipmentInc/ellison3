require "savon"

class Valutec

  CLIENT_KEY = Rails.env == "production" ? '45bf3191-79e6-4883-818f-c93a35e98cc7' : '45c4ddcc-feb1-4cb1-99f0-1ba71d6d8f69'
  TERMINAL_ID =  Rails.env == "production" ? is_sizzix? ? '156026' : '156027' : '153189'

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
    @client ||= Savon::Client.new("http://ws.valutec.net/Valutec.asmx?WSDL")
  end

  def soap_actions
    client.wsdl.soap_actions
  end

  def method_missing(key, *args)
    if client.wsdl.soap_actions.include? key
      @response = client.request(key) do
        soap.body = {
          "ClientKey" => CLIENT_KEY,
          "TerminalID" => TERMINAL_ID,
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
      results[:card_amount_used].to_i
    end
  end

  def errors
    unless authorized?
      {
        "CARD NOT ACTIVE" => "The gift card number you entered was not valid. Please check your number and try again",
        "CARD NOT FOUND" => "The gift card number you entered was not valid. Please check your number and try again",
        "CARD DEACTIVATED" => "The gift card number you entered was not valid. Please check your number and try again",
        "CANNOT ACCEPT CARD" => "The pin number you entered was not valid. Please check your pin and try again"
      }[results[:error_msg]] || results[:error_msg]
    end
  end

end

