class Admin::ReportsController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  @start_date = Time.zone.now.beginning_of_day
	  @end_date = Time.zone.now.end_of_day
	  @campaigns = Rails.cache.fetch("disctinct_campaign_names_#{current_system}", :expires_in => 1.hour.since) {Order.send(current_system).distinct('order_items.campaign_name').compact.sort {|x,y| x.downcase <=> y.downcase}}
	  @coupons = Rails.cache.fetch("disctinct_coupon_names_#{current_system}", :expires_in => 1.hour.since) {Order.send(current_system).distinct('order_items.coupon_name').compact.sort {|x,y| x.downcase <=> y.downcase}}
	  @shipping_coupons = Rails.cache.fetch("disctinct_order_coupon_names_#{current_system}", :expires_in => 1.hour.since) {Coupon.send(current_system).any_of({:free_shipping => true}, {:level.in => %w(shipping group)}).sort {|x,y| x.name <=> y.name}.map {|e| ["#{e.name} - #{e.codes * ', '}", e.id]}}
	end
	
	def order_analysis
	  @report = Report.create :start_date => params[:start_date], :end_date => params[:end_date], :system => current_system
	  @report.delay.order_analysis
	  render :process
	end
	
	def order_summary
	  @original_locale = current_locale
    @order_summary = Order.summary :start_date => Time.parse(params[:start_date]), :end_date => Time.parse(params[:end_date]), :system => params[:order_system]
    @order_statuses = Order.status_summary :start_date => Time.parse(params[:start_date]), :end_date => Time.parse(params[:end_date]), :system => params[:order_system]
	end
	
	def wishlists_report
	  criteria = List.listable.where(:owns.ne => true, :created_at.gt => Time.parse(params[:start_date]), :created_at.lt => Time.parse(params[:end_date]), :system => params[:order_system])
		#@total_wishlists = criteria.count
		@wishlist_users = criteria.distinct(:user_id).count
		@items_per_lists = List.items_per_list :system => params[:order_system], :query => {:created_at => {"$gt" => Time.parse(params[:start_date]), "$lt" => Time.parse(params[:end_date])}, :active => true, :save_for_later => {"$ne"=>true}, :owns => {"$ne"=>true}, :system => params[:order_system]}
	end
	
	def get_status
	  @report = Report.find(params[:id])
	  render :text => @report.percent.to_i
	end
	
	def campaign_usage_report
	  if params[:campaign].blank?
	    render :js => "alert('select campaign from the dropdown')"
	  else
	    @report = Report.create :report_options => {:name => params[:campaign].parameterize}, :system => current_system
  	  @report.delay.campaign_coupon_usage(params[:campaign])
  	  render :process
	  end
	end
	
	def coupon_usage_report
	  if params[:coupon].blank?
	    render :js => "alert('select coupon from the dropdown')"
	  else
  	  @report = Report.create :report_options => {:name => params[:coupon].parameterize}, :system => current_system
  	  @report.delay.campaign_coupon_usage params[:coupon], "coupon"
  	  render :process
  	end
	end
	
	def shipping_coupon_usage_report
	  if params[:coupon].blank?
	    render :js => "alert('select coupon from the dropdown')"
	  else
	    @coupon = Coupon.find(params[:coupon])
  	  @report = Report.create :report_options => {:name => @coupon.name.parameterize}, :system => current_system
  	  @report.delay.shipping_coupon_usage @coupon.id
  	  render :process
  	end
	end
	
	def download_report
	  @report = Report.find(params[:id])
    @gridfs_file = Mongo::GridFileSystem.new(Mongoid.database).open(@report.file_name, 'r')
	  send_data  @gridfs_file.read, :filename => "#{@report.report_type}_#{@report.report_options['name'].present? ? @report.report_options['name']+'_' : ''}#{Time.zone.now.strftime "%m%d%Y_%s"}.csv", :type => @gridfs_file.content_type
	end
	

end
