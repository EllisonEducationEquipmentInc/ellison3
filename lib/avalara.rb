require 'curb'

class Avalara

  ACCOUNT_NUMBER = '1100047148'
  LICENSE_KEY = '84143DB82A1BD04E'
  URL = Rails.env.production? ? 'https://avatax.avalara.net/' : 'https://development.avalara.net/'

  attr_accessor :cart, :items, :total, :customer, :shipping_charge, :handling_charge, :response,
    :total_tax, :transaction_id, :exempt, :referred_id, :merchant_transaction_id, :tax_exempt_certificate

  def initialize(attributes)
    @cart = attributes[:cart]                         # cart object
    @items = @cart ? @cart.cart_items : attributes[:items]               # cart_item, or order_item object
    @total = @cart ? @cart.taxable_amaunt : attributes[:total]  # order subtotal
    @customer = attributes[:customer]                 # Address object
    @shipping_charge = attributes[:shipping_charge]   # decimal
    @handling_charge = attributes[:handling_charge]   # decimal
    @transaction_id = attributes[:transaction_id]
    @exempt = attributes[:exempt] || false            # tax exempt: boolean
    @referred_id = attributes[:referred_id]
    @tax_exempt_certificate = attributes[:tax_exempt_certificate].present? ? attributes[:tax_exempt_certificate] : nil
    @merchant_transaction_id = attributes[:merchant_transaction_id] || order_prefix
  end

  def calculate
    c = Curl::Easy.new
    c.url = URL + '1.0/tax/get'
    c.username = ACCOUNT_NUMBER
    c.password = LICENSE_KEY
    c.http_post construct_body.to_json
    @response = JSON.parse c.body_str
  end

private

  def construct_body
    {
      "CustomerCode" => @customer.user.try(:erp),
      "DocDate" =>Date.today.strftime("%Y-%m-%d"),
      "CompanyCode" => "ELL",
      "Client" => "AvaTaxSample",
      "DocCode" => @cart.is_a?(Order) ? @cart.order_number : @cart.id,
      "DetailLevel" => "Tax",
      "Commit" => "false",
      "DocType" => "SalesOrder",
      "ExemptionNo" => @tax_exempt_certificate,
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
        "Amount" => (item.quantity * (item.respond_to?(:sale_price) ? item.sale_price : item.product.coupon_price(cart)).to_f).to_f,
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
    handling_item = if @handling_charge.present?
      {
        "LineNo" => @i += 1,
        "ItemCode" => 'handling',
        "Qty" => "1",
        "Amount" => @handling_charge,
        "OriginCode" => "01",
        "DestinationCode" => "02",
        "Description" => 'Shipping Charge',
        "TaxCode" => 'FR020100'
      }
    end

    line_items << shipping_item
    line_items << handling_item
    line_items.compact
  end
end
