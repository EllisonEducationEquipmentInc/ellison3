require 'rubygems'
require 'builder'

module Ax
   
  # include EllisonSystem
  # include ShoppingCart
  
  module ClassMethods
    
  end
  
  module InstanceMethods
        
    PATH = Rails.env == 'development' ? "#{Rails.root}" : "/data/shared"
    
    def calculate_tax?(state)
      %w(CA IN WA UT).include?(state)
    end
    
    def format_with_precision(number, precision=2)
      "%.*f" % [precision, number]
    end
    
    def build_ax_xml(orders)
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!
      xml.salesorders do
        orders.each do |order|
          xml.order {
            xml.header {
              xml.sales_id(order.public_order_number)
              xml.ax_customer(order.system == "szus" ? "SIZZIX.COM" : order.user.try(:erp))      # ax_ship_to
              xml.invoice_account(order.system == "szus" ? "SIZZIX.COM" : order.user.try(:invoice_account))     # ax_bill_to
              xml.cust_name("#{order.address.first_name} #{order.address.last_name}")
              xml.email(order.address.email)
              xml.currency_code(LOCALES_2_CURRENCIES[order.locale.to_s].upcase)
              xml.source_code(order.coupon_code)
              xml.sales_recipient(order.customer_rep)
              xml.sales_responsible(order.customer_rep)
              xml.sales_origin(order.order_prefix(order.system))
              xml.giftcard_order order.gift_card? ? "TRUE" : "FALSE"

              xml.payment {
                if order.payment.present? || order.gift_card.present?
                  xml.freight_charges(format_with_precision(order.shipping_amount))
                  xml.surcharge(format_with_precision(order.handling_amount))

                  xml.tax {
                    xml.tax_transaction_id(order.tax_transaction)
                    xml.tax_amount(format_with_precision(order.tax_amount + order.shipping_vat))
                    tax_calculated_at = order.tax_calculated_at.in_time_zone("America/Chicago").strftime("%m/%d/%Y") unless order.tax_calculated_at.blank?
                    xml.tax_trans_date(tax_calculated_at)
                    xml.tax_exempt_num(order.tax_exempt_number)
                    xml.VAT_percentage(order.vat_percentage)
                  }
                  xml.payment_type {
                    if order.payment.present?
                      xml.type {
                        if order.payment.try :purchase_order
                          xml.payment_method('Terms')
                          xml.payment_id(order.payment.purchase_order_number)
                        elsif order.payment.try :deferred
                          xml.payment_method('3EZ')
                          xml.payment_id(order.system == "szuk" || order.system == "eeuk" ? order.payment.tx_auth_no : order.payment.vpstx_id)
                        elsif order.payment.present?
                          xml.payment_method('CC')
                          xml.card_type(order.payment.card_name)
                          xml.payment_id(order.system == "szuk" || order.system == "eeuk" ? order.payment.tx_auth_no : order.payment.vpstx_id)
                        end
                        xml.cybersource_merchant_ref_num(order.payment.vendor_tx_code)
                        xml.amount_charged(format_with_precision(order.gift_card.present? ? order.payment.paid_amount : order.total_amount))
                        if order.payment.present? && order.payment.reference_purchase_order_number.present?
                          xml.ref_purchase_order_number order.payment.reference_purchase_order_number
                        end
                      }
                    end
                    if order.gift_card.present?
                      xml.type {
                        xml.payment_method('GC')
                        xml.giftcard_num(order.gift_card.card_number)
                        xml.giftcard_identifier(order.gift_card.vendor_tx_code)
                        xml.giftcard_auth_num(order.gift_card.authorization)
                        xml.giftcard_amount_charged(format_with_precision(order.gift_card.paid_amount))
                      }
                    end
                  }
                  billing_address = order.payment.present? ? order.payment : order.gift_card
                  xml.invoice_address {
                    xml.invoice_contact_first(billing_address.first_name)
                    xml.invoice_contact_last(billing_address.last_name)
                    xml.invoice_company(billing_address.company)
                    xml.street(billing_address.address2.blank? ? billing_address.address1 : "#{billing_address.address1} #{billing_address.address2}")
                    xml.zip_code(billing_address.zip_code)
                    xml.city(billing_address.city)
                    xml.state(billing_address.state)
                    xml.country(country_2_code billing_address.country)
                    xml.phone_num(billing_address.phone)
                  }
                end
              }

              xml.delivery {
                xml.delivery_zone(order.address.us? && order.address.try(:zip_code) ? FedexZone.find_by_zip(order.address.zip_code).try(:zone) : '')
                xml.delivery_mode(order.cod? ? order.cod_account_type : ax_shipping_code(order.shipping_service))
                xml.priority(order.shipping_priority)
                xml.delivery_term(order.cod? ? 'CC' : 'PP')
                xml.delivery_ship_account(order.cod_account) if order.cod?
                xml.delivery_contact_first order.address.first_name
                xml.delivery_contact_last order.address.last_name

                xml.delivery_address {
                  ship_date = order.estimated_ship_date.strftime("%m/%d/%Y") unless order.estimated_ship_date.blank?
                  xml.ship_date(ship_date)

                  xml.ship_company(order.address.company)
                  xml.street(order.address.address2.blank? ? order.address.address1 :
                                                            "#{order.address.address1} #{order.address.address2}")
                  xml.zip_code(order.address.zip_code)
                  xml.city(order.address.city)
                  xml.state(order.address.state)
                  xml.country(country_2_code order.address.country)
                  xml.ship_phone(order.address.phone)
                }
              }

              xml.order_comments(order.comments.blank? ? '' : order.comments.to_xs)
            }

            xml.lines {
              i = 1
              order.order_items.each do |item|
                xml.line({ 'num' => i,
                  'item_number' => item.item_num,
                  'qty' => item.quantity,
                  'unit_price' => format_with_precision(item.quoted_price),
                  'discount_amount' => format_with_precision(item.quoted_price - item.sale_price),
                  'VAT_amount' => item.vat,
                  'upsell' => item.upsell ? 'UPSELL' : ''})
                i += 1
              end
            }
          }
        end
      end
      xml.target!
    end
    
    def order_status_update(xml, no_emails = false)
      begin
        doc = REXML::Document.new(xml)
        doc.root.elements.each('orders') do |orders|
          orders.elements.each('order') do |order|
            order_number = order.attributes['number']
            tracking_number = order.attributes['tracking_number']
            tracking_url = order.attributes['tracking_url']
            tracking_url = "http://www.fedex.com/Tracking?ascend_header=1&clienttype=dotcom&cntry_code=us&language=english&tracknumbers=#{tracking_number}" if !tracking_number.blank? && tracking_url =~ /fedex/i
            carrier_description = order.attributes['carrier_description']
            state = order.attributes['status'].blank? ? '' : order.attributes['status'].strip.downcase

            dborder = Order.find_by_public_order_number order_number
            unless dborder.blank?
              if state =~ /^shipped$/i
                order_status = "Shipped"
              elsif state =~ /^cancel(l?)ed$/i
                order_status = dborder.payment.try(:purchase_order) ? 'Cancelled' : "To Refund"
              elsif state =~ /^processing$/i
                order_status = "Processing"
              elsif state =~ /^in(\s|-)process$/i
                order_status = "In Process"
              elsif state =~ /^on(\s|-)hold$/i
                order_status = "On Hold"
              else
                next
              end
              
              # TODO: handle invalid order_status, cch failure
              set_current_system dborder.system
              dborder.update_attributes!(:status => order_status, :tracking_number => tracking_number, :tracking_url => tracking_url, :carrier_description => carrier_description)              
              if order_status == "Shipped"
                dborder.send_shipping_confirmation unless no_emails || dborder.system == "szuk" || dborder.system == "eeuk"
                dborder.delay.delete_billing_subscription_id if dborder.system == "eeus" && dborder.payment.present? && dborder.payment.subscriptionid.present?
                #commit_tax(dborder) if !dborder.tax_committed
              end
            end

          end
        end
        return 1
      rescue Exception => e
        return e #.backtrace
      end
    end
    
    def update_inventory_from_ax(xml, options = {})
      doc = REXML::Document.new(xml)
      doc.root.elements.each('items') do |items|
        items.elements.each('item') do |item|
          item_number = item.attributes['number']
          onhand_qty_wh01 = item.attributes['onhand_qty_wh1'].to_i 
          onhand_qty_wh11 = item.attributes['onhand_qty_wh11'].to_i
          onhand_qty_uk = item.attributes['onhand_qty_uk'].blank? ? nil : item.attributes['onhand_qty_uk'].to_i
          new_life_cycle = case item.attributes['life_cycle']
          when "Pre-Release"
            'pre-release'
          when 'Active'
            'available'
          when 'Discontinued'
            'discontinued'
          when 'Inactive'
            'unavailable'
          else
            nil
          end
          product = Product.first(:conditions => {:item_num => item_number})
          unless product.blank?
            product.quantity_us =  onhand_qty_wh01 < 1 ? 0 : onhand_qty_wh01 unless options[:exclude] == "quantity_us"
            product.quantity_sz =  onhand_qty_wh11 < 1 ? 0 : onhand_qty_wh11 unless options[:exclude] == "quantity_sz"
            product.quantity_uk =  onhand_qty_uk < 1 ? 0 : onhand_qty_uk unless onhand_qty_uk.nil? || options[:exclude] == "quantity_uk"             
            if new_life_cycle
              product.life_cycle = new_life_cycle
              if item.attributes['life_cycle_date'].present? && item.attributes['life_cycle_date'] =~ /^\d{2}\/\d{2}\/\d{2,4}$/
                life_cycle_date = Date.new(item.attributes['life_cycle_date'].split("/")[2].to_i, item.attributes['life_cycle_date'].split("/")[0].to_i, item.attributes['life_cycle_date'].split("/")[1].to_i) 
                product.life_cycle_date = life_cycle_date
              end
            end
            product.save(:validate => false)
            Rails.logger.info "*** updating #{product.id} #{product.item_num}, life_cycle: #{new_life_cycle ? new_life_cycle : '--- not changed ---'}, onhand_qty_wh01: #{onhand_qty_wh01}, onhand_qty_wh11: #{onhand_qty_wh11}, onhand_qty_uk: #{onhand_qty_uk}" 
          else
            Rails.logger.info "!!! inventory on-hand quantity of #{item_number} could not be updated"
          end
        end
      end
      return 1
    rescue Exception => e
      return e
    end
    
    def create_status_update_xml(orders, options = {})
      options[:state] ||= 'In Process'
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.instruct!
      xml.tag!(:order_status_update) {
        xml.orders {
          orders.each do |order|
            xml.order(:number => order.public_order_number, :status => options[:state], :tracking_url => '', :tracking_number => '')
          end
        }
      }
      xml.target!
    end
    
    def ax_shipping_code(shipping_service)
      case shipping_service
      when "EXPRESS_SAVER", "FEDEX_EXPRESS_SAVER"
        "FDXES"
      when "FEDEX_GROUND", "GROUND"
        "FXGround"
      when "FEDEX_2_DAY", "SECOND_DAY"
        "FDX2D"
      when "FIRST_OVERNIGHT"
        "FXDFONIGHT"
      when "STANDARD_OVERNIGHT", "OVERNIGHT"
        "FDXSO"
      when "PRIORITY_OVERNIGHT"
        "FDXPO"
      when "INTERNATIONAL_ECONOMY"
        "FDXIE"
      when "FEDEX_3_DAY_FREIGHT"
        "FDXTHRDFR"
      else
        'FXGround'
      end
    end
    
  
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
end
