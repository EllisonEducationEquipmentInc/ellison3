class Admin::TagsController < ApplicationController
  layout 'admin'
	
	before_filter :authenticate_admin!
	
	def index
	  criteria = Mongoid::Criteria.new(Tag)
	  criteria.where(:systems_enabled.in => params[:systems_enabled]) unless params[:systems_enabled].blank?
	  criteria.where(:active => true) unless params[:inactive].blank?
	  criteria.where(:tag_type => params[:tag_type]) unless params[:tag_type].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :name => regexp})
	  end
		@tags = criteria.paginate :page => params[:page], :per_page => 100
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
end
