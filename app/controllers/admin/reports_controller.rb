class Admin::ReportsController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  @start_date = Time.zone.now.beginning_of_day
	  @end_date = Time.zone.now.end_of_day
	end
	
	def order_analysis
	  @report = Report.create :start_date => params[:start_date], :end_date => params[:end_date]
	  @report.delay.order_analysis
	  render :process
	end
	
	def order_summary
	  @original_locale = current_locale
    @order_summary = Order.summary :start_date => Time.parse(params[:start_date]), :end_date => Time.parse(params[:end_date]), :system => params[:order_system]
    @order_statuses = Order.status_summary :start_date => Time.parse(params[:start_date]), :end_date => Time.parse(params[:end_date]), :system => params[:order_system]
	end
	
	def get_status
	  @report = Report.find(params[:id])
	  render :text => @report.percent.to_i
	end
	
	def download_report
	  @report = Report.find(params[:id])
    @gridfs_file = Mongo::GridFileSystem.new(Mongoid.database).open(@report.file_name, 'r')
	  send_data  @gridfs_file.read, :filename => "#{@report.report_type}_#{Time.zone.now.strftime "%m%d%Y_%s"}.csv", :type => @gridfs_file.content_type
	end
end
