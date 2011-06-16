class Admin::LandingPagesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(LandingPage)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp}, { :search_query => regexp}, { :permalink => regexp})
	  end
		@landing_pages = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 100
	end

  # GET /landing_pages/1
  # GET /landing_pages/1.xml
  def show
    @landing_page = LandingPage.find(params[:id])
    @time = params[:time].blank? ? Time.zone.now : Time.zone.parse(params[:time])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @landing_page }
    end
  end

  # GET /landing_pages/new
  # GET /landing_pages/new.xml
  def new
    @landing_page = LandingPage.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @landing_page }
    end
  end

  # GET /landing_pages/1/edit
  def edit
    @landing_page = LandingPage.find(params[:id])
  end

  # POST /landing_pages
  # POST /landing_pages.xml
  def create
    @landing_page = LandingPage.new(params[:landing_page])
    respond_to do |format|
      if @landing_page.save
        format.html { redirect_to(admin_landing_pages_url, :notice => 'LandingPage was successfully created.') }
        format.xml  { render :xml => @landing_page, :status => :created, :location => @landing_page }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @landing_page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /landing_pages/1
  # PUT /landing_pages/1.xml
  def update
    @landing_page = LandingPage.find(params[:id])
    @landing_page.attributes = params[:landing_page]
    respond_to do |format|
      if @landing_page.save
        format.html { redirect_to(admin_landing_pages_url, :notice => 'LandingPage was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @landing_page.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /landing_pages/1
  # DELETE /landing_pages/1.xml
  def destroy
    @landing_page = LandingPage.find(params[:id])
    @landing_page.destroy

    respond_to do |format|
      format.html { redirect_to(admin_landing_pages_url) }
      format.xml  { head :ok }
    end
  end
  
  def reorder_visual_assets
    @landing_page = LandingPage.find(params[:id])
    @landing_page.visual_assets.resort! params[:visual_asset]
    @landing_page.save
    render :text => params[:visual_asset].inspect
  rescue Exception => e
    render :js => "alert('ERROR saving visual asset order: make sure all visual assets are saved before you resort them. (save/update landing page first and then come back to resort them)')"
  end

end
