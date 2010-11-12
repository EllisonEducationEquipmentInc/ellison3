class Admin::ShippingRatesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(ShippingRate)
	  criteria.where :deleted_at => nil
	  if params[:systems_enabled].blank?
	    criteria.where(:system => current_system)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :zone_or_country => regexp})
	  end
		@shipping_rates = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /shipping_rates/1
  # GET /shipping_rates/1.xml
  def show
    @shipping_rate = ShippingRate.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @shipping_rate }
    end
  end

  # GET /shipping_rates/new
  # GET /shipping_rates/new.xml
  def new
    @shipping_rate = ShippingRate.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @shipping_rate }
    end
  end

  # GET /shipping_rates/1/edit
  def edit
    @shipping_rate = ShippingRate.find(params[:id])
  end

  # POST /shipping_rates
  # POST /shipping_rates.xml
  def create
    @shipping_rate = ShippingRate.new(params[:shipping_rate])
    respond_to do |format|
      if @shipping_rate.save
        format.html { redirect_to(edit_admin_shipping_rate_path(@shipping_rate), :notice => 'ShippingRate was successfully created.') }
        format.xml  { render :xml => @shipping_rate, :status => :created, :location => @shipping_rate }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @shipping_rate.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /shipping_rates/1
  # PUT /shipping_rates/1.xml
  def update
    @shipping_rate = ShippingRate.find(params[:id])
    respond_to do |format|
      if @shipping_rate.update_attributes(params[:shipping_rate])
        format.html { redirect_to(admin_shipping_rates_path, :notice => 'ShippingRate was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @shipping_rate.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /shipping_rates/1
  # DELETE /shipping_rates/1.xml
  def destroy
    @shipping_rate = ShippingRate.find(params[:id])
    @shipping_rate.destroy

    respond_to do |format|
      format.html { redirect_to(admin_shipping_rates_url) }
      format.xml  { head :ok }
    end
  end
  
private

  def get_zone_or_countries
    zones = [["USA Zones", FedexZone::ZONES], ["Countries", countries]]
  end
end
