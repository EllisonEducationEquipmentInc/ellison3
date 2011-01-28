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
      @cch = CCH::Cch.new(:action => 'calculate', :customer => @order.address, :shipping_charge => @order.shipping_amount, :handling_charge => @order.handling_amount.present? ? @order.handling_amount : 0.0, :total => @order.subtotal_amount, :exempt => @order.tax_exempt, :tax_exempt_certificate => @order.tax_exempt_number)
      if @cch.success?
        VirtualTransaction.create(:user => current_admin.employee_number, :transaction_type => "cch_calculate", :result => @cch.total_tax.to_s, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => @order.attributes.to_hash})
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
      VirtualTransaction.create(:user => current_admin.employee_number, :transaction_type => "cch_commit", :result => "Committed", :raw_result => @cch.pretty, :transaction_id => params[:cch_commit_tax_transaction_id], :details => {:transaction_id => params[:cch_commit_tax_transaction_id]})
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
      VirtualTransaction.create(:user => current_admin.employee_number, :transaction_type => "cch_return", :result => @cch.total_tax.to_s, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => order.attributes.to_hash})
      render :text => "Total Tax: #{@cch.total_tax} CCH Transaction ID: #{@cch.transaction_id}"
    else
      render :text => @cch.errors #pretty(:request)
    end
	rescue Exception => e
    render :text => e
  end
	
	def cc_purchase
	  order = Order.new(params[:cc_purchase])	  
    if params[:purchase_total_amount].to_f > 0
      process_card(:amount => (params[:purchase_total_amount].to_f * 100).round, :payment => order.payment, :order => params[:purchase_order_id], :capture => params[:purchase_transaction_type] != "authorize", :use_payment_token => false, :system => params[:purchase_system])
      VirtualTransaction.create(:user => current_admin.employee_number, :transaction_type => params[:purchase_transaction_type], :result => @payment.status, :raw_result => @payment.authorization, :transaction_id => @payment.security_key, :details => {:payment => @payment.attributes.to_hash})
    end
    text = ""
    ["subscriptionid", "cv2_result", "status", "vpstx_id", "security_key", "tx_auth_no", "status_detail", "address_result", "post_code_result", "paid_amount", "authorization"].each do |s|
      text << "#{s.titleize}: #{@payment.send(s)}<br />"
    end
    text << "<br>AX URL Encoded Authorization string: #{CGI::escape(@payment.authorization)}" if @payment.authorization
    render :text => text
  rescue Exception => e
    render :text => e.to_s #+ "\n" + e.backtrace.join("\n")
	end
	
	def cc_capture
    get_gateway params[:cc_capture_system]
    @net_response = @gateway.capture(params[:cc_capture_total_amount].to_f * 100, params[:authorization])
    if @net_response.success?
      VirtualTransaction.create(:user => current_admin.employee_number, :transaction_type => "cc_capture", :result => @net_response.params.inspect, :raw_result => @net_response.inspect, :transaction_id => @net_response.authorization, :details => {:amount_to_charge => params[:cc_capture_total_amount], :authorization => params[:authorization]})
    else
      raise @net_response.message
    end
    render :text => "Authorization: #{@net_response.authorization}, #{@net_response.params.inspect} <br>AX URL Encoded Authorization string: #{CGI::escape(@net_response.authorization)}"
  rescue Exception => e
    render :text => e
	end
end
