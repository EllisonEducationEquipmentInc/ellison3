class Admin::UsersController < ApplicationController
	layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_token]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(User)
	  criteria = criteria.where :deleted_at => nil
	  criteria = criteria.where :_id.in => current_admin.users.map {|e| e.id} if current_admin.limited_sales_rep
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp}, { :email => regexp })
	  end
		@users = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@user)
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    @user = User.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@user)
  end

  # POST /users
  # POST /users.xml
  def create
    @user = User.new(params[:user])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@user)
    mass_assign_protected_attributes
    @user.created_by = current_admin.email
    respond_to do |format|
      if @user.save
        format.html { redirect_to(admin_users_url, :notice => 'User was successfully created.') }
        format.xml  { render :xml => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    @user = User.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@user)
    mass_assign_protected_attributes
    @user.updated_by = current_admin.email
    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to(admin_users_url, :notice => 'User was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def view_retailer_application
    @user = User.find(params[:id])
  end

  def edit_token
    @user = User.find(params[:id])
  end
  
  def update_token
    @user = User.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@user)
    redirect_to({:action => "edit_token", :id => @user.id}, :alert => "Invalid Token") and return unless params[:subscriptionid] && params[:subscriptionid] =~ /^\d{20,24}$/
    @user.token.try :delete
    @user.token = Token.new :subscriptionid => params[:subscriptionid]
    @user.token.save :validate => false
    redirect_to({:action => "index"}, :notice => "Token has been saved")
  end
  
private 

	def mass_assign_protected_attributes
	  [:systems_enabled, :invoice_account, :erp, :tax_exempt_certificate, :tax_exempt, :purchase_order, :status, :discount_level, :admin_id, :first_order_minimum, :order_minimum].each do |meth|
	    @user.send("#{meth}=", params[:user][meth])
	  end
	end	
end
