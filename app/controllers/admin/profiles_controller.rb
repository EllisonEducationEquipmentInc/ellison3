class Admin::ProfilesController < ApplicationController
	layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Admin)
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp}, { :email => regexp }, {:employee_number => regexp})
	  end
		@admins = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /admins/1
  # GET /admins/1.xml
  def show
    @admin = Admin.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @admin }
    end
  end

  # GET /admins/new
  # GET /admins/new.xml
  def new
    @admin = Admin.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @admin }
    end
  end

  # GET /admins/1/edit
  def edit
    @admin = Admin.find(params[:id])
  end

  # POST /admins
  # POST /admins.xml
  def create
    @admin = Admin.new(params[:admin])
    mass_assign_protected_attributes
    @admin.created_by = current_admin.email
    respond_to do |format|
      if @admin.save
        format.html { redirect_to(admin_admins_url, :notice => 'Admin was successfully created.') }
        format.xml  { render :xml => @admin, :status => :created, :location => @admin }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @admin.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /admins/1
  # PUT /admins/1.xml
  def update
    @admin = Admin.find(params[:id])
		mass_assign_protected_attributes
    respond_to do |format|
      if @admin.update_attributes(params[:admin])
        format.html { redirect_to(admin_admins_url, :notice => 'Admin was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @admin.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /admins/1
  # DELETE /admins/1.xml
  def destroy
    @admin = Admin.find(params[:id])
    @admin.update_attributes :active => false

    respond_to do |format|
      format.html { redirect_to(admin_admins_url) }
      format.xml  { head :ok }
    end
  end

private 
	
	# these attributes can only be changed by an admin who has write permissions to change admin profiles
	def mass_assign_protected_attributes
	  @admin.systems_enabled = params[:admin][:systems_enabled]
		@admin.active = params[:admin][:active]
		@admin.permissions_attributes = params[:admin][:permissions_attributes]
		@admin.can_act_as_customer = params[:admin][:can_act_as_customer]
		@admin.can_change_prices = params[:admin][:can_change_prices]
		@admin.updated_by = current_admin.email
	end
end
