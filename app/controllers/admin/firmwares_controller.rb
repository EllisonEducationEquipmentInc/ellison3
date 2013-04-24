class Admin::FirmwaresController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create_range, :upload_file, :edit, :update, :destroy, :update_text, :destroy_firmware_range]
	
	ssl_exceptions
	
	#verify :method => :post, :only => [:update_text, :upload_file]
	
	def index
	  @text = SystemSetting.value_at("firmware_text") || SystemSetting.new(:key => "firmware_text").value
	  @files = Firmware.active.asc(:created_at)
	  @firmware = Firmware.new
	  @firmware_ranges = FirmwareRange.active.asc(:created_at)
	  @firmware_range = FirmwareRange.new
	end
	
	def update_text
	  @text = SystemSetting.find_by_key("firmware_text") || SystemSetting.new(:key => "firmware_text")
	  @text.updated_by = current_admin.email
	  @text.value = params[:text]
	  @text.save
	  render :nothing => true
	end
	
	def upload_file
	  @firmware = Firmware.new(params[:firmware])
	  @firmware.created_by = current_admin.email
	end
	
	def destroy
	  @firmware = Firmware.find(params[:id])
	  @firmware.destroy
	  render :js => "$('#firmware_file_#{@firmware.id}').remove()"
	end
	
	def create_range
	  @firmware_range = FirmwareRange.new(params[:firmware_range])
	  @firmware_range.created_by = current_admin.email
	end
	
	def destroy_firmware_range
	  @firmware_range = FirmwareRange.find(params[:id])
	  @firmware_range.destroy
	  render :js => "$('#firmware_range_#{@firmware_range.id}').remove()"
	end
	
	def change_display_order
	  @firmware = Firmware.find(params[:id])
    @firmware.update_attributes :display_order => params[:update_value]
    render :text =>  @firmware.display_order
	end
	
	def change_name
    @firmware = Firmware.find(params[:id])
    @firmware.update_attributes :name => params[:update_value]
    render :text =>  @firmware.name
	end
	
end
