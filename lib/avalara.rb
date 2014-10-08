require 'curb'

class Avalara

  ACCOUNT_NUMBER = '1100047148'
  LICENSE_KEY = '84143DB82A1BD04E'
  URL = Rails.env.production? ? 'https://avatax.avalara.net/' : 'https://development.avalara.net/'

  attr_accessor :cart, :items, :total, :customer, :shipping_charge, :handling_charge, :response,
    :total_tax, :transaction_id, :exempt, :referred_id, :merchant_transaction_id, :tax_exempt_certificate

  def initialize(attributes)
    @cart = attributes[:cart]                         # cart object
    @items = attributes[:items] || (@cart.is_a?(Cart) ? @cart.cart_items : @cart.order_items)  # cart_item, or order_item object
    @total = attributes[:total] || (@cart.is_a?(Cart) ? @cart.taxable_amaunt : @cart.subtotal_amount)  # order subtotal
    @customer = attributes[:customer]                 # Address object
    @shipping_charge = attributes[:shipping_charge]   # decimal
    @handling_charge = attributes[:handling_charge]   # decimal
    @transaction_id = attributes[:transaction_id]
    @exempt = attributes[:exempt] || false            # tax exempt: boolean
    @referred_id = attributes[:referred_id]
    @tax_exempt_certificate = attributes[:tax_exempt_certificate].present? ? attributes[:tax_exempt_certificate] : nil
    @merchant_transaction_id = attributes[:merchant_transaction_id] || order_prefix
    calculate
  end

  def calculate
    c = Curl::Easy.new
    c.url = URL + '1.0/tax/get'
    c.username = ACCOUNT_NUMBER
    c.password = LICENSE_KEY
    c.http_post construct_body.to_json
    @response = JSON.parse c.body_str
  end

  def total_tax
    @response["TotalTax"].to_f
  end

  def transaction_id
    @response["DocCode"]
  end

  def error?
    !success?
  end

  def success?
    @response["ResultCode"] == "Success"
  end

  def correct_address
    return unless @confirm_address
    begin
      corrected_address = response["TaxAddresses"][0]
      @customer.city = corrected_address["City"]
      @customer.zip_code = corrected_address["PostalCode"]
      @customer.state = corrected_address["Region"]
      @customer.address1 = corrected_address["Address"]
    rescue Exception => e
    end
  end

  def pretty
    @response
  end

  def errors
    @response["Messages"] unless success?
  end

private

  def construct_body
    {
      "CustomerCode" => @customer.user.try(:erp) || 'New',
      "DocDate" =>Date.today.strftime("%Y-%m-%d"),
      "CompanyCode" => "ELL",
      "Client" => "AvaTaxSample",
      "DocCode" => @cart.is_a?(Order) ? @cart.order_number : @cart.try(:id),
      "DetailLevel" => "Tax",
      "Commit" => "false",
      "DocType" => "SalesOrder",
      "ExemptionNo" => (is_ee_us? || is_er_us?) && @exempt ? @tax_exempt_certificate : nil,
      "CurrencyCode" => "USD",
      "Addresses" => [
        {
          "AddressCode" => "01",
          "Line1" => '25862 Commercentre Drive',
          "City" => 'Lake Forest',
          "Region" => 'CA',
          "Country" => 'US',
          "PostalCode" => '92630'
        },
        {
          "AddressCode" => "02",
          "Line1" => @customer.address1,
          "Line2" => @customer.address2,
          "City" => @customer.city,
          "Region" => @customer.state,
          "Country" => Country.name_2_code(@customer.country),
          "PostalCode" => @customer.zip_code
        },
      ],
      "Lines" =>  generate_line_items
    }
  end


  def generate_line_items
    @i = 0
    line_items = @items.map do |item|
      {
        "LineNo" => @i += 1,
        "ItemCode" => item.item_num,
        "Qty" => item.quantity,
        "Amount" => (@cart.is_a?(Cart) ? item.total : item.item_total ).to_f.round(2),
        "OriginCode" => "01",
        "DestinationCode" => "02",
        "Description" => item.name,
        "TaxCode" => item.gift_card ? 'PG050000' : nil,
        "TaxIncluded" => "false"
      }
    end


    shipping_item = if @shipping_charge.present?
        {
          "LineNo" => @i += 1,
          "ItemCode" => 'shipping',
          "Qty" => "1",
          "Amount" => @shipping_charge,
          "OriginCode" => "01",
          "DestinationCode" => "02",
          "Description" => 'Shipping Charge',
          "TaxCode" => 'FR020100'
        }
      end
    handling_item = if @handling_charge.present? && @handling_charge > 0
      {
        "LineNo" => @i += 1,
        "ItemCode" => 'handling',
        "Qty" => "1",
        "Amount" => @handling_charge,
        "OriginCode" => "01",
        "DestinationCode" => "02",
        "Description" => 'Handling Charge',
        "TaxCode" => 'OHO10000'
      }
    end

    line_items << shipping_item
    line_items << handling_item
    line_items.compact
  end
end
