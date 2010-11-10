class Admin::UsShippingRatesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(FedexRate)
	  criteria.where :deleted_at => nil
		@fedex_rates = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /fedex_rates/1
  # GET /fedex_rates/1.xml
  def show
    @fedex_rate = FedexRate.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @fedex_rate }
    end
  end

  # GET /fedex_rates/new
  # GET /fedex_rates/new.xml
  def new
    @fedex_rate = FedexRate.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @fedex_rate }
    end
  end

  # GET /fedex_rates/1/edit
  def edit
    @fedex_rate = FedexRate.find(params[:id])
  end

  # POST /fedex_rates
  # POST /fedex_rates.xml
  def create
    @fedex_rate = FedexRate.new(params[:fedex_rate])
    respond_to do |format|
      if @fedex_rate.save
        format.html { redirect_to(edit_admin_fedex_rate_path(@fedex_rate), :notice => 'FedexRate was successfully created.') }
        format.xml  { render :xml => @fedex_rate, :status => :created, :location => @fedex_rate }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @fedex_rate.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /fedex_rates/1
  # PUT /fedex_rates/1.xml
  def update
    @fedex_rate = FedexRate.find(params[:id])
    respond_to do |format|
      if @fedex_rate.update_attributes(params[:fedex_rate])
        format.html { redirect_to(admin_fedex_rates_path, :notice => 'FedexRate was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @fedex_rate.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /fedex_rates/1
  # DELETE /fedex_rates/1.xml
  def destroy
    @fedex_rate = FedexRate.find(params[:id])
    @fedex_rate.destroy

    respond_to do |format|
      format.html { redirect_to(admin_fedex_rates_url) }
      format.xml  { head :ok }
    end
  end
end
