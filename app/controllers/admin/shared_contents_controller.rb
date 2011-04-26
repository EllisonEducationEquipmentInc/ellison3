class Admin::SharedContentsController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(SharedContent)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  criteria = criteria.where(:placement => params[:placement] == 'none' ? '' : params[:placement]) unless params[:placement].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp}, { :short_desc => regexp})
	  end
		@shared_contents = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 100
	end

  # GET /shared_contents/1
  # GET /shared_contents/1.xml
  def show
    @shared_content = SharedContent.find(params[:id])
    @time = params[:time].blank? ? Time.zone.now : Time.zone.parse(params[:time])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @shared_content }
    end
  end

  # GET /shared_contents/new
  # GET /shared_contents/new.xml
  def new
    @shared_content = SharedContent.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @shared_content }
    end
  end

  # GET /shared_contents/1/edit
  def edit
    @shared_content = SharedContent.find(params[:id])
  end

  # POST /shared_contents
  # POST /shared_contents.xml
  def create
    @shared_content = SharedContent.new(params[:shared_content])
    @shared_content.created_by = current_admin.email
    respond_to do |format|
      if @shared_content.save
        format.html { redirect_to(admin_shared_contents_url(:placement => @shared_content.placement), :notice => 'SharedContent was successfully created.') }
        format.xml  { render :xml => @shared_content, :status => :created, :location => @shared_content }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @shared_content.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /shared_contents/1
  # PUT /shared_contents/1.xml
  def update
    @shared_content = SharedContent.find(params[:id])
    @shared_content.attributes = params[:shared_content]
    @shared_content.updated_by = current_admin.email
    respond_to do |format|
      if @shared_content.save
        format.html { redirect_to(admin_shared_contents_url(:placement => @shared_content.placement), :notice => 'SharedContent was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @shared_content.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /shared_contents/1
  # DELETE /shared_contents/1.xml
  def destroy
    @shared_content = SharedContent.find(params[:id])
    @shared_content.destroy

    respond_to do |format|
      format.html { redirect_to(admin_shared_contents_url) }
      format.xml  { head :ok }
    end
  end
  
  def reorder_visual_assets
    @shared_content = SharedContent.find(params[:id])
    @shared_content.visual_assets.resort! params[:visual_asset]
    @shared_content.save
    render :text => params[:visual_asset].inspect
  rescue Exception => e
    render :js => "alert('ERROR saving visual asset order: make sure all visual assets are saved before you resort them. (save/update landing page first and then come back to resort them)')"
  end
  
  def shared_contents_autocomplete
		@shared_contents = SharedContent.active.only(:name, :short_desc, :id).where({:name => Regexp.new("#{params[:term]}", "i")}).asc(:name).limit(20).all.map {|p| {:label => "#{p.name} (#{p.short_desc})", :value => p.name, :id => p.id}}
		render :json => @shared_contents.to_json
	end
end
