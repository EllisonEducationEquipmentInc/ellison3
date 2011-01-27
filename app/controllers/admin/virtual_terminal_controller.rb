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
      VirtualTransaction.create(:user => current_user, :transaction_type => "cch_return", :result => @cch.total_tax.to_s, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => order.attributes.to_hash})
      render :text => "Total Tax: #{@cch.total_tax} CCH Transaction ID: #{@cch.transaction_id}"
    else
      render :text => @cch.errors #pretty(:request)
    end
	rescue Exception => e
    render :text => e
  end
	
	def cc_purchase
	  
	end
end
