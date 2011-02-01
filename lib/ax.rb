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
              xml.ax_customer(order.system == "szus" ? "SIZZIX.COM" : order.user.try(:invoice_account))      # ax_ship_to
              xml.invoice_account(order.system == "szus" ? "SIZZIX.COM" : order.user.try(:invoice_account))     # ax_bill_to
              xml.cust_name("#{order.address.first_name} #{order.address.last_name}")
              xml.email(order.address.email)
              xml.currency_code(LOCALES_2_CURRENCIES[order.locale.to_s].upcase)
              xml.source_code(order.coupon_code)
              xml.sales_recipient(order.customer_rep)
              xml.sales_responsible(order.customer_rep)
              xml.sales_origin(order.order_prefix(order.system))

              xml.payment {
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

                if order.payment.try :purchase_order
									xml.payment_method('Terms')
                  xml.payment_id(order.payment.purchase_order_number)
								elsif order.payment.try :deferred
									xml.payment_method('3EZ')
                  xml.payment_id(order.payment.vpstx_id)
                else
									xml.payment_method('CC')
									xml.card_type(order.payment.card_name)
                  xml.payment_id(order.payment.vpstx_id)
                end
                xml.cybersource_merchant_ref_num(order.payment.vendor_tx_code)
                xml.amount_charged(format_with_precision(order.total_amount))

                xml.invoice_address {
                  xml.invoice_contact_first(order.payment.first_name)
                  xml.invoice_contact_last(order.payment.last_name)
                  xml.invoice_company(order.payment.company)
                  xml.street(order.payment.address2.blank? ? order.payment.address1 : "#{order.payment.address1} #{order.payment.address2}")
                  xml.zip_code(order.payment.zip_code)
                  xml.city(order.payment.city)
                  xml.state(order.payment.state)
                  xml.country(country_2_code order.payment.country)
                  xml.phone_num(order.payment.phone)
                }
              }

              xml.delivery {
                xml.delivery_mode(order.shipping_service)
                xml.priority(order.shipping_priority)
                xml.delivery_term('PP')
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
                  'upsell' => item.upsell })
                i += 1
              end
            }
          }
        end
      end
			xml.target!
		end
		
		def order_status_update(xml)
			begin
				doc = REXML::Document.new(xml)
		    doc.root.elements.each('orders') do |orders|
		      orders.elements.each('order') do |order|
		        order_number = order.attributes['number']
		        tracking_number = order.attributes['tracking_number']
		        tracking_url = order.attributes['tracking_url']
		        tracking_url = "http://www.fedex.com/Tracking?ascend_header=1&clienttype=dotcom&cntry_code=us&language=english&tracknumbers=#{tracking_number}" if !tracking_number.blank? && tracking_url =~ /fedex/i
		        state = order.attributes['status'].blank? ? '' : order.attributes['status'].strip.downcase

	          dborder = Order.find_by_public_order_number order_number
	          unless dborder.blank?
	            if state =~ /^shipped$/i
	              order_status = "Shipped"
	            elsif state =~ /^cancel(l?)ed$/i
	              order_status = dborder.payment.try :purchase_order ? 'Cancelled' : "To Refund"
	            elsif state =~ /^processing$/i
	              order_status = "Processing"
	            elsif state =~ /^in(\s|-)process$/i
	              order_status = "In Process"
	            else
	              next
	            end
							
							# TODO: handle invalid order_status, cch failure
	            dborder.update_attributes!(:status => order_status, :tracking_number => tracking_number, :tracking_url => tracking_url)
	            #commit_tax(dborder) if order_status == OrderStatus.shipped && !dborder.tax_committed
	          end

		      end
				end
				return 1
			rescue Exception => e
				return e #.backtrace
			end
		end
		
		def update_inventory_from_ax(xml)
			begin
				doc = REXML::Document.new(xml)
		    doc.root.elements.each('items') do |items|
		      items.elements.each('item') do |item|
		        item_number = item.attributes['number']
		        quantity = item.attributes['onhand_qty'].to_i
						
						product = Product.find_by_axapta_id item_number
						unless product.blank?
		          product.set_quantity(quantity) 
							ActionController::Base.logger.info "*** updating inventory on-hand quantity of #{product.id} #{product.axapta_id}, quantity: #{quantity}" 
						else
							ActionController::Base.logger.info "!!! inventory on-hand quantity of #{item_number} could not be updated"
						end
		      end
		    end
				return 1
			rescue Exception => e
				return e
			end
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
	
	end
	
	def self.included(receiver)
		receiver.extend         ClassMethods
		receiver.send :include, InstanceMethods
	end
end