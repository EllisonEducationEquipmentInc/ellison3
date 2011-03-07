class Admin::CouponsController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Coupon)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  criteria = criteria.where(:level => params[:level]) unless params[:level].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :codes => regexp}, { :name => regexp })
	  end
		@coupons = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /coupons/1
  # GET /coupons/1.xml
  def show
    @coupon = Coupon.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @coupon }
    end
  end

  # GET /coupons/new
  # GET /coupons/new.xml
  def new
    @coupon = Coupon.new :"start_date_#{current_system}" => Time.zone.now.beginning_of_day, :"end_date_#{current_system}" => Time.zone.now.end_of_day
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @coupon }
    end
  end

  # GET /coupons/1/edit
  def edit
    @coupon = Coupon.find(params[:id])
  end

  # POST /coupons
  # POST /coupons.xml
  def create
    process_cart_must_have
    @coupon = Coupon.new(params[:coupon])
    @coupon.created_by = current_admin.email
    respond_to do |format|
      if @coupon.save
        format.html { redirect_to(edit_admin_coupon_url(@coupon), :notice => 'Coupon was successfully created.') }
        format.xml  { render :xml => @coupon, :status => :created, :location => @coupon }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @coupon.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /coupons/1
  # PUT /coupons/1.xml
  def update
    @coupon = Coupon.find(params[:id])
    process_cart_must_have
    @coupon.updated_by = current_admin.email
    respond_to do |format|
      if @coupon.update_attributes(params[:coupon])
        format.html { redirect_to(admin_coupons_url, :notice => 'Coupon was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @coupon.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /coupons/1
  # DELETE /coupons/1.xml
  def destroy
    @coupon = Coupon.find(params[:id])
    @coupon.destroy

    respond_to do |format|
      format.html { redirect_to(admin_coupons_url) }
      format.xml  { head :ok }
    end
  end
  
private

  def process_cart_must_have
    params[:coupon][:cart_must_have] ||= []
    params[:coupon][:cart_must_have] = params[:coupon][:cart_must_have].map {|e| {e.values[0] => e.values[1].split(/,\s*/)}}
  end
end
