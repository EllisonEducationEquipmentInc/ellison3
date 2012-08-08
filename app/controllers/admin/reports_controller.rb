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
    @coupons = Rails.cache.fetch("disctinct_coupon_codes_#{current_system}", :expires_in => 1.hour.since) {Order.send(current_system).distinct('order_items.coupon_code').compact.sort {|x,y| x.downcase <=> y.downcase}}
    @shipping_coupons = Rails.cache.fetch("disctinct_order_coupon_codes_#{current_system}", :expires_in => 1.hour.since) {Order.send(current_system).where(:free_shipping_by_coupon => true).distinct('coupon_code').compact.sort {|x,y| x.downcase <=> y.downcase}}
    @all_coupons = Rails.cache.fetch("all_disctinct_coupon_codes_#{current_system}", :expires_in => 1.hour.since) {Coupon.only(:codes, :id).where(:_id.in => Order.send(current_system).distinct(:coupon_id)).map {|e| e}}
    @tags = Rails.cache.fetch("all_report_tags_#{current_system}", :expires_in => 1.hour.since) {Tag.send(current_system).where(:tag_type.in => ["designer", "artist", "special", "exclusive", "theme", "product_line", "subcategory"]).order_by([:tag_type, :name]).only(:tag_type).group.each_with_object({}) {|e, h| h[e["tag_type"]] = e["group"].sort {|x,y| x.name <=> y.name }.map {|i| [i.name, i.id]}}}
  end
  
  def order_analysis
    @report = Report.create :start_date => params[:start_date], :end_date => params[:end_date], :system => current_system
    @report.delay.order_analysis
    render :process
  end
  
  def order_summary
    @original_locale = current_locale
    @order_summary = Order.summary :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => params[:order_system]
    @order_statuses = Order.status_summary :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => params[:order_system]
  end
  
  def wishlists_report
    criteria = List.listable.where(:owns.ne => true, :created_at.gt => Time.zone.parse(params[:start_date]), :created_at.lt => Time.zone.parse(params[:end_date]), :system => params[:order_system])
    #@total_wishlists = criteria.count
    @wishlist_users = criteria.distinct(:user_id).count
    @items_per_lists = List.items_per_list :system => params[:order_system], :query => {:created_at => {"$gt" => Time.zone.parse(params[:start_date]).utc, "$lt" => Time.zone.parse(params[:end_date]).utc}, :active => true, :save_for_later => {"$ne"=>true}, :owns => {"$ne"=>true}, :system => params[:order_system]}
  end
  
  def get_status
    @report = Report.find(params[:id])
    render :text => @report.percent.to_i
  end
  
  def campaign_usage_report
    if params[:campaign].blank?
      render :js => "alert('select campaign from the dropdown')"
    else
      @report = Report.create :report_options => {:name => params[:campaign].parameterize}, :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => current_system
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
      @report = Report.create :report_options => {:name => params[:coupon].parameterize}, :system => current_system
      @report.delay.shipping_coupon_usage params[:coupon]
      render :process
    end
  end
  
  def product_performance_report
    if params[:tag].blank?
      render :js => "alert('select tag from the dropdown')"
    else
      @tag = Tag.find params[:tag]
      @report = Report.create :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => current_system
      @report.delay.product_performance @tag
      render :process
    end
  end
  
  def customer_report
    if params[:tag].blank?
      render :js => "alert('select tag from the dropdown')"
    else
      @tag = Tag.find params[:tag]
      @report = Report.create :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => current_system
      @report.delay.customer_report @tag
      render :process
    end
  end
  
  def coupon_summary_report
    @coupon_summary_report = Order.send(current_system).not_cancelled.where(:coupon_id => params[:coupon]).count
    render :js => "$('#coupon_summary_report').html('#{@coupon_summary_report}')"
  end
  
  def customer_summary_report
    @customer_summary = User.where(:systems_enabled.in => [current_system], :created_at.gt => Time.zone.parse(params[:start_date]), :created_at.lt => Time.zone.parse(params[:end_date])).count 
    render :js => "$('#customer_summary_report').html('#{@customer_summary}')"
  end

  def active_quotes_report
    @report = Report.create :start_date => Time.zone.parse(params[:start_date]), :end_date => Time.zone.parse(params[:end_date]), :system => current_system
    @report.delay.active_quotes_report
    render :process
  end

  def real_time_stock_status_reports
    @report = Report.create  :system => current_system
    sleep 1
    @report = Report.find @report.id
    @report.delay.real_time_stock_status_reports
    render :process
  end
  
  def download_report
    @report = Report.find(params[:id])
    @gridfs_file = Mongo::GridFileSystem.new(Mongoid.database).open(@report.file_name, 'r')
    send_data  @gridfs_file.read, :filename => "#{@report.report_type}_#{@report.report_options['name'].present? ? @report.report_options['name']+'_' : ''}#{Time.zone.now.strftime "%m%d%Y_%s"}.csv", :type => @gridfs_file.content_type
  end
  

end
