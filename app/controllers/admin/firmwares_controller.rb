class Admin::FirmwaresController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create_range, :upload_file, :edit, :update, :destroy, :update_text, :destroy_firmware_range]
	
	ssl_exceptions
	
	verify :post => true, :only => [:update_text, :upload_file]
	
	def index
	  @text = SystemSetting.value_at("firmware_text") || SystemSetting.new(:key => "firmware_text").value
	  @files = Firmware.active.asc(:created_at)
	  @firmware = Firmware.new
	  @firmware_ranges = FirmwareRange.active.asc(:created_at)
	  @firmware_range = FirmwareRange.new
	end
	
	def update_text
	  @text = SystemSetting.value_at("firmware_text") || SystemSetting.new(:key => "firmware_text")
	  @text.update_attribute :value, params[:text]
	  render :nothing => true
	end
	
	def upload_file
	  @firmware = Firmware.new(params[:firmware])
	end
	
	def destroy
	  @firmware = Firmware.find(params[:id])
	  @firmware.destroy
	  render :js => "$('#firmware_file_#{@firmware.id}').remove()"
	end
	
	def create_range
	  @firmware_range = FirmwareRange.new(params[:firmware_range])
	end
	
	def destroy_firmware_range
	  @firmware_range = FirmwareRange.find(params[:id])
	  @firmware_range.destroy
	  render :js => "$('#firmware_range_#{@firmware_range.id}').remove()"
	end
	
end
