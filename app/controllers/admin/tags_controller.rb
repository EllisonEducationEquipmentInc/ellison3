class Admin::TagsController < ApplicationController
  layout 'admin'
	
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Tag)
	  if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria.where(:active => true) if params[:inactive].blank?
	  criteria.where(:tag_type => params[:tag_type]) unless params[:tag_type].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :name => regexp})
	  end
		@tags = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /tags/1
  # GET /tags/1.xml
  def show
    @tag = Tag.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
    @tag = Tag.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    @tag = Tag.find(params[:id])
  end

  # POST /tags
  # POST /tags.xml
  def create
    @tag = Tag.new(params[:tag])
    populate_campaign
    respond_to do |format|
      if @tag.save
        format.html { redirect_to(admin_tags_url, :notice => 'Tag was successfully created.') }
        format.xml  { render :xml => @tag, :status => :created, :location => @tag }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
    @tag = Tag.find(params[:id])
    params[:tag][:my_product_ids] ||= []
    @tag.write_attributes(params[:tag])
    populate_campaign
    respond_to do |format|
      if @tag.update_attributes(params[:tag])
        format.html { redirect_to(admin_tags_url, :notice => 'Tag was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/1
  # DELETE /tags/1.xml
  def destroy
    @tag = Tag.find(params[:id])
    @tag.destroy

    respond_to do |format|
      format.html { redirect_to(admin_tags_url) }
      format.xml  { head :ok }
    end
  end
  
  def tags_autocomplete
		@tags = Tag.available.only(:name, :tag_type, :id).where({:name => Regexp.new("#{params[:term]}", "i")}).asc(:name).limit(20).all.map {|p| {:label => "#{p.name} (#{p.tag_type.humanize})", :value => p.name, :id => p.id}}
		render :json => @tags.to_json
	end

private
  
  def populate_campaign
    if @tag.campaign? 
      @tag.campaign ||= Campaign.new 
      @tag.campaign.write_attributes params[:tag].delete(:campaign).merge(:name => @tag.name, :systems_enabled => @tag.systems_enabled, :start_date => @tag.send("start_date_#{current_system}"), :end_date => @tag.send("end_date_#{current_system}"), :name => @tag.name, :short_desc => @tag.description)
    else
      @tag.campaign = nil
    end
  end
end
