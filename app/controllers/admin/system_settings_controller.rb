class Admin::SystemSettingsController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :save_vat]
	
	ssl_exceptions
	
	def index
	  @vat = SystemSetting.value_at("vat").to_f
	  @free_shipping_message = SystemSetting.value_at("free_shipping_message_#{current_system}")
	end
	
	def save_vat
	  if params[:update_value].present?
	    SystemSetting.update :vat, params[:update_value].to_f
	    Rails.cache.delete 'vat'
	  end
	  render :text => SystemSetting.value_at("vat").to_f
	end
	
	def save_free_shipping_message
	  @free_shipping_message = SystemSetting.find_by_key("free_shipping_message_#{current_system}") || SystemSetting.new(:key => "free_shipping_message_#{current_system}")
	  @free_shipping_message.value = params[:update_value]
	  @free_shipping_message.save :validate => false
	  Rails.cache.delete "free_shipping_message_#{current_system}"
	  render :text => @free_shipping_message.value
	end
end
