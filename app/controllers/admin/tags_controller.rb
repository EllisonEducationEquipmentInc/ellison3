class Admin::TagsController < ApplicationController
  layout 'admin'
  
  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
  
  ssl_exceptions
  
  def index
    criteria = Mongoid::Criteria.new(Tag)
    criteria = criteria.where :deleted_at => nil
    criteria = if params[:systems_enabled].blank?
      criteria.where(:systems_enabled.in => admin_systems)
    else
      criteria.where(:systems_enabled.in => params[:systems_enabled]) 
    end
    criteria = criteria.where(:active => true) if params[:inactive].blank?
    criteria = criteria.where(:tag_type => params[:tag_type]) unless params[:tag_type].blank?
    if params[:q].present?
      criteria = criteria.where({ :name => params[:extended] == "1" ? /#{params[:q]}/i : /^#{params[:q]}/})
      @tags = criteria.paginate :page => params[:page], :per_page => 50
    else
      @tags = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
    end
  end

  # GET /tags/1
  # GET /tags/1.xml
  def show
    @tag = Tag.find(params[:id])
    @time = params[:time].blank? ? Time.zone.now : Time.zone.parse(params[:time])
    @products = Product.available(current_system, @time).where(:tag_ids.in => [@tag.id]).paginate(:page => params[:page], :per_page => 50) if @tag.campaign? || @tag.tag_type == 'exclusive'
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/new
  # GET /tags/new.xml
  def new
    @tag = Tag.new
    @tag.build_campaign
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @tag }
    end
  end

  # GET /tags/1/edit
  def edit
    @tag = Tag.find(params[:id])
    @tag.build_campaign if @tag.campaign.blank?
    @ideas = @tag.get_related_paginated "ideas", :sort => [[:idea_num, :asc]]
    @products = @tag.get_related_paginated "products", :sort => [[:item_num, :asc]]
  end
  
  def more_products
    @tag = Tag.find(params[:id])
    @products = @tag.get_related_paginated "products", :sort => [[:item_num, :asc]],  :page => params[:page]
    render :partial => 'tag_products'
  end
  
  def more_ideas
    @tag = Tag.find(params[:id])
    @ideas = @tag.get_related_paginated "ideas", :sort => [[:idea_num, :asc]], :page => params[:page]
    render :partial => 'tag_ideas'
  end

  # POST /tags
  # POST /tags.xml
  def create
    @tag = Tag.new(params[:tag])
    @tag.created_by = current_admin.email
    populate_campaign
    respond_to do |format|
      if @tag.save
        format.html { redirect_to(edit_admin_tag_url(@tag), :notice => 'Tag was successfully created.') }
        format.xml  { render :xml => @tag, :status => :created, :location => @tag }
      else
        @tag.build_campaign if @tag.campaign.blank?
        format.html { render :action => "new" }
        format.xml  { render :xml => @tag.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /tags/1
  # PUT /tags/1.xml
  def update
    @tag = Tag.find(params[:id])
    @tag.write_attributes(params[:tag])
    @tag.updated_by = current_admin.email
    populate_campaign
    respond_to do |format|
      if @tag.save #update_attributes(params[:tag])
        format.html { redirect_to(admin_tags_url, :notice => 'Tag was successfully updated.') }
        format.xml  { head :ok }
      else
        @tag.build_campaign if @tag.campaign.blank?
        @ideas = @tag.get_related_paginated "ideas", :sort => [[:idea_num, :asc]]
        @products = @tag.get_related_paginated "products", :sort => [[:item_num, :asc]]
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
    @tags = Tag.active.only(:name, :tag_type, :id).where({:name => Regexp.new("#{params[:term]}", "i")}).asc(:name).limit(20).all.map {|p| {:label => "#{p.name} (#{p.tag_type.humanize})", :value => p.name, :id => p.id}}
    render :json => @tags.to_json
  end
  
  def reorder_visual_assets
    @tag = Tag.find(params[:id])
    @tag.visual_assets.resort! params[:visual_asset]
    @tag.save
    render :text => params[:visual_asset].inspect
  rescue Exception => e
    render :js => "alert('ERROR saving visual asset order: make sure all visual assets are saved before you resort them. (save/update landing page first and then come back to resort them)')"
  end

  def remove_product
    @tag = Tag.find(params[:id])
    @product = Product.find(params[:product_id])
    @tag.remove_from_collection :products, @product
    @product.delay.index if @tag.active
    render :js => "$('li#product_#{@product.id}').remove()"
  end
  
  def remove_all_products
    @tag = Tag.find(params[:id])
    @tag.nullify_collection :products
    #@tag.save(:validate => false)
    #Delayed::Job.enqueue HeavyJob.new @tag, :products, :nullify, :save, :validate => false
    render :js => "$('#tag_products li').remove()"
  end
  
  def add_product
    @tag = Tag.find(params[:id])
    @product = Product.find(params[:product_id])
    @tag.add_to_collection :products, @product
    @product.index_by_tag(@tag) if @tag.active 
    render(:partial => 'product', :object => @product, :locals => {:tag_id => @tag.id})
  end
  
  def remove_idea
    @tag = Tag.find(params[:id])
    @idea = Idea.find(params[:idea_id])
    @tag.remove_from_collection :ideas, @idea
    @idea.delay.index if @tag.active
    render :js => "$('li#idea_#{@idea.id}').remove()"
  end
  
  def add_idea
    @tag = Tag.find(params[:id])
    @idea = Idea.find(params[:idea_id])
    @tag.add_to_collection :ideas, @idea
    @idea.index_by_tag(@tag) if @tag.active 
    render(:partial => 'idea', :object => @idea, :locals => {:tag_id => @tag.id})
  end
  
private
  
  def populate_campaign
    if @tag.campaign? 
      @tag.campaign ||= Campaign.new(:created_by => current_admin.email)
      @tag.campaign.write_attributes(:name => @tag.name, :systems_enabled => @tag.systems_enabled, :start_date => @tag.send("start_date_#{current_system}"), :end_date => @tag.send("end_date_#{current_system}"), :short_desc => @tag.description, :updated_by => current_admin.email)
      @tag.embed_campaign = true if @tag.new_record? && @tag.campaign.individual
    else
      params[:tag].delete :campaign
      @tag.campaign = nil
    end
  end
end
