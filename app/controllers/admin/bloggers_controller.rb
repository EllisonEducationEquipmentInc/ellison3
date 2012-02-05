class Admin::BloggersController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions

  def index
	  criteria = Mongoid::Criteria.new(Blogger)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp})
	  end
		@bloggers = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /bloggers/1
  # GET /bloggers/1.xml
  def show
    @blogger = Blogger.find(params[:id])
    render :file => 'index/blogger.html.haml'
  end

  # GET /bloggers/new
  # GET /bloggers/new.xml
  def new
    @blogger = Blogger.new 

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @blogger }
    end
  end

  # GET /bloggers/1/edit
  def edit
    @blogger = Blogger.find(params[:id])
  end

  # POST /bloggers
  # POST /bloggers.xml
  def create
    @blogger = Blogger.new(params[:blogger])
    @blogger.created_by = current_admin.email
    respond_to do |format|
      if @blogger.save
        format.html { redirect_to(admin_bloggers_url, :notice => 'Blogger was successfully created.') }
        format.xml  { render :xml => @blogger, :status => :created, :location => @blogger }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @blogger.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /bloggers/1
  # PUT /bloggers/1.xml
  def update
    @blogger = Blogger.find(params[:id])
    @blogger.updated_by = current_admin.email
    respond_to do |format|
      if @blogger.update_attributes(params[:blogger])
        format.html { redirect_to(admin_bloggers_url, :notice => 'Blogger was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @blogger.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /bloggers/1
  # DELETE /bloggers/1.xml
  def destroy
    @blogger = Blogger.find(params[:id])
    @blogger.destroy

    respond_to do |format|
      format.html { redirect_to(admin_bloggers_url) }
      format.xml  { head :ok }
    end
  end

end
