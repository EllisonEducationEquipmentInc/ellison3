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
        #VirtualTransaction.create(:user => current_user, :transaction_type => "cch_calculate", :result => @cch.total_tax, :raw_result => @cch.pretty, :transaction_id => @cch.transaction_id, :details => {:order => order.attributes})
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
end
