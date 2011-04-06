class Admin::VirtualTerminalController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  params[:order] ||= {}
	  params[:order][:address] ||= params[:address] if params[:address].present?
	  params[:order][:payment] ||= {}
	  params[:order][:payment].merge! params[:address] if params[:address].present? && params[:order][:payment].blank?
	  @order = Order.new(params[:order])
	  @order.build_address unless @order.address
	  @order.build_payment unless @order.payment
	end
	
	def cch_calculate
	  @order = Order.new(params[:cch_calculate])
    if calculate_tax?(@order.address.state) || @order.address.country == "Canada"
      @cch = CCH::Cch.new(:action => 'calculate', :customer => @order.address, :shipping_charge => @order.shipping_amount, :handling_charge => @order.handling_amount.present? ? @order.handling_amount : 0.0, :total => @order.subtotal_amount, :exempt => @order.tax_exempt, :tax_exempt_certificate => @order.tax_exempt_number, :merchant_transaction_id => params[:order_number])
      if @cch.success?
        VirtualTransaction.create(:user => current_admin.email, :transaction_type => "cch_calculate", :result => @cch.total_tax.to_s, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => @order.attributes.to_hash})
        render :text => "Total Tax: #{@cch.total_tax} CCH Transaction ID: #{@cch.transaction_id}"
      else
        render :text => @cch.errors
      end
    else
      render :text => "no cch call required for this shipping address"
    end
	rescue Exception => e
    render :text => e  
	end
	
	def cch_commit
    @cch = CCH::Cch.new(:action => 'commit', :transaction_id => params[:cch_commit_tax_transaction_id])
    if @cch.success?
      VirtualTransaction.create(:user => current_admin.email, :transaction_type => "cch_commit", :result => "Committed", :raw_result => @cch.pretty, :transaction_id => params[:cch_commit_tax_transaction_id], :details => {:transaction_id => params[:cch_commit_tax_transaction_id]})
      render :text => "#{params[:cch_commit_tax_transaction_id]} committed"
    else
      render :text => @cch.errors
    end
	rescue Exception => e
    render :text => e
	end
	
	def cch_return
    order = Order.new(params[:cch_return])
    @cch = CCH::Cch.new(:action => 'ProcessAttributedReturn', :shipping_charge => order.shipping_amount, :handling_charge => order.handling_amount.present? ? order.handling_amount : 0.0, :total => order.subtotal_amount, :transaction_id => order.tax_transaction)
    if @cch.success?
      VirtualTransaction.create(:user => current_admin.email, :transaction_type => "cch_return", :result => @cch.total_tax.to_s, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => order.attributes.to_hash})
      render :text => "Total Tax: #{@cch.total_tax} CCH Transaction ID: #{@cch.transaction_id}"
    else
      render :text => @cch.errors #pretty(:request)
    end
	rescue Exception => e
    render :text => e
  end
	
	def cc_purchase
	  @original_system = current_system
	  set_current_system params[:purchase_system]
	  order = Order.new(params[:cc_purchase])	  
	  order.payment.subscriptionid = nil if order.payment.subscriptionid.blank?
    process_card(:amount => (params[:purchase_total_amount].to_f * 100).round, :payment => order.payment, :order => params[:purchase_order_id], :capture => params[:purchase_transaction_type] != "authorize", :use_payment_token => order.payment.subscriptionid.present?, :system => params[:purchase_system], :no_user => true)
    VirtualTransaction.create(:user => current_admin.email, :transaction_type => params[:purchase_transaction_type], :result => @payment.status, :raw_result => @payment.authorization, :transaction_id => @payment.security_key, :details => {:payment => @payment.attributes.to_hash})
    text = ""
    ["subscriptionid", "cv2_result", "status", "vpstx_id", "security_key", "tx_auth_no", "status_detail", "address_result", "post_code_result", "paid_amount", "authorization"].each do |s|
      text << "#{s.titleize}: #{@payment.send(s)}<br />"
    end
    text << "<br>AX URL Encoded Authorization string: #{CGI::escape(@payment.authorization)}" if @payment.authorization
    render :text => text
  rescue Exception => e
    render :text => e.to_s + "\n" + e.backtrace.join("\n")
  ensure
    set_current_system @original_system 
	end
	
	def cc_capture
	  @original_system = current_system
	  set_current_system params[:cc_capture_system]
    get_gateway params[:cc_capture_system]
    @net_response = @gateway.capture(params[:cc_capture_total_amount].to_f * 100, params[:authorization])
    if @net_response.success?
      VirtualTransaction.create(:user => current_admin.email, :transaction_type => "cc_capture", :result => @net_response.params.inspect, :raw_result => @net_response.inspect, :transaction_id => @net_response.authorization, :details => {:amount_to_charge => params[:cc_capture_total_amount], :authorization => params[:authorization]})
    else
      raise @net_response.message
    end
    render :text => "Authorization: #{@net_response.authorization}, #{@net_response.params.inspect} <br>AX URL Encoded Authorization string: #{CGI::escape(@net_response.authorization)}"
  rescue Exception => e
    render :text => e
  ensure
    set_current_system @original_system
	end
	
	def cc_refund
	  @original_system = current_system
	  set_current_system params[:cc_refund_system]
    get_gateway params[:cc_refund_system]
    options = is_uk? ? {:order_id => Digest::SHA1.hexdigest("#{Time.now.to_f}-#{params[:refund_authorization]}"), :description => "refund"} : {}
    timeout(50) do
			@net_response = @gateway.credit(params[:amount_to_refund].to_f * 100, params[:refund_authorization], options)
		end
    if @net_response.success?
      VirtualTransaction.create(:user => current_admin.email, :transaction_type => "cc_refund", :result => @net_response.params.inspect, :raw_result => @net_response.inspect, :transaction_id => @net_response.authorization, :details => {:amount_to_refund => params[:amount_to_refund], :authorization => params[:refund_authorization]})
    else
      raise @net_response.message
    end
    render :text => "Authorization: #{@net_response.authorization}, #{@net_response.params.inspect}"
  rescue Exception => e
    render :text => e
  ensure
    set_current_system @original_system
	end
	
	def shipping_rate_calculator
	  order = Order.new(params[:shipping_rate])	
	  case params[:service]
	  when "FEDEX"
      fedex_rate order.address, :weight => params[:weight], :packaging_type => params[:packaging_type], :request_type => params[:request_type], :package_width => params[:package_width], :package_length => params[:package_length], :package_height => params[:package_height], :package_count => params[:package_count]  
  	  render :text => fedex_rates_to_a(@rates) * '<br />'
	  when "SAIA"
	    @saia = Saia::Saia.new(:user_id => "somchine", :password => "ellison2", :account_number => "0855387", :destination_city => order.address.city, :destination_state => order.address.state, :destination_zip_code => order.address.zip_code, :weight => params[:weight], :test => Rails.env != "production")
      render :text => @saia.rate.inspect
	  when "WEB"
	    if is_us? && !is_ee?
			  us_shipping_rate(order.address, :weight => params[:weight]) || fedex_rate(order.address, :request_type => params[:request_type], :weight => params[:weight], :packaging_type => params[:packaging_type], :package_width => params[:package_width], :package_length => params[:package_length], :package_height => params[:package_height], :package_count => params[:package_count] )
			else
			  shipping_rate(order.address, :subtotal_amount => params[:shipping_rate][:subtotal_amount])
			end
			render :text => fedex_rates_to_a(@rates) * '<br />'
	  end
	rescue Exception => e
    render :text => e
	end
	
	def get_account
	  @user = User.where(:erp => params[:erp_id]).first
	end
	
end
