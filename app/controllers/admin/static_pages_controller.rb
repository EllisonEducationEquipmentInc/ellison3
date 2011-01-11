class Admin::StaticPagesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(StaticPage)
	  criteria.where :deleted_at => nil
	  if params[:system_enabled].blank?
	    criteria.where(:system_enabled.in => admin_systems)
	  else
	    criteria.where(:system_enabled.in => params[:systems_enabled]) 
	  end
	  criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :name => regexp}, { :short_desc => regexp}, { :permalink => regexp})
	  end
		@static_pages = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 100
	end

  # GET /static_pages/1
  # GET /static_pages/1.xml
  def show
    @static_page = StaticPage.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @static_page }
    end
  end

  # GET /static_pages/new
  # GET /static_pages/new.xml
  def new
    @static_page = StaticPage.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @static_page }
    end
  end

  # GET /static_pages/1/edit
  def edit
    @static_page = StaticPage.find(params[:id])
  end

  # POST /static_pages
  # POST /static_pages.xml
  def create
    @static_page = StaticPage.new(params[:static_page])
    respond_to do |format|
      if @static_page.save
        format.html { redirect_to(admin_static_pages_url, :notice => 'StaticPage was successfully created.') }
        format.xml  { render :xml => @static_page, :status => :created, :location => @static_page }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @static_page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /static_pages/1
  # PUT /static_pages/1.xml
  def update
    @static_page = StaticPage.find(params[:id])
    @static_page.attributes = params[:static_page]
    respond_to do |format|
      if @static_page.save
        format.html { redirect_to(admin_static_pages_url, :notice => 'StaticPage was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @static_page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /static_pages/1
  # DELETE /static_pages/1.xml
  def destroy
    @static_page = StaticPage.find(params[:id])
    @static_page.destroy

    respond_to do |format|
      format.html { redirect_to(admin_static_pages_url) }
      format.xml  { head :ok }
    end
  end
end
