class Admin::IdeasController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Idea)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :idea_num => regexp}, { :name => regexp }, {:short_desc => regexp})
	  end
		@ideas = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /ideas/1
  # GET /ideas/1.xml
  def show
    @idea = Idea.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @idea }
    end
  end

  # GET /ideas/new
  # GET /ideas/new.xml
  def new
    @idea = Idea.new :"start_date_#{current_system}" => Time.zone.now.beginning_of_day, :"end_date_#{current_system}" => Time.zone.now.end_of_day

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @idea }
    end
  end

  # GET /ideas/1/edit
  def edit
    @idea = Idea.find(params[:id])
  end

  # POST /ideas
  # POST /ideas.xml
  def create
    @idea = Idea.new(params[:idea])

    respond_to do |format|
      if @idea.save
        format.html { redirect_to(edit_admin_idea_url(@idea), :notice => 'Idea was successfully created.') }
        format.xml  { render :xml => @idea, :status => :created, :location => @idea }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @idea.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /ideas/1
  # PUT /ideas/1.xml
  def update
    @idea = Idea.find(params[:id])
    respond_to do |format|
      if @idea.update_attributes(params[:idea])
        format.html { redirect_to(admin_ideas_url, :notice => 'Idea was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @idea.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /ideas/1
  # DELETE /ideas/1.xml
  def destroy
    @idea = Idea.find(params[:id])
    @idea.destroy

    respond_to do |format|
      format.html { redirect_to(admin_ideas_url) }
      format.xml  { head :ok }
    end
  end

	
	# image methods
	def new_image
		@idea = Idea.find(params[:id])
		@image = @idea.images.build
	end
	
	def upload_image
		@idea = Idea.find(params[:idea_id])
		@image = @idea.images.build(params[:image])
		@image.save
	end
	
	def delete_image
		@idea = Idea.find(params[:idea_id])
		@idea.images.find(params[:id]).delete
	end
	
	# tab methods
	def new_tab
		@idea = Idea.find(params[:id])
		@tab = @idea.tabs.build
	end
	
	def reusable_tab
		@idea = Idea.find(params[:id])
	end
	
	def create_tab
		@idea = Idea.find(params[:idea_id])
		@tab = @idea.tabs.build(params[:tab])
	end
	
	def edit_tab
		@idea = Idea.find(params[:idea_id])
		@tab = @idea.tabs.find(params[:id])
	end
	
	def update_tab
		@idea = Idea.find(params[:idea_id])
		@tab = @idea.tabs.find(params[:id])
		@tab.write_attributes params[:tab]
		@tab.save
	end
	
	def delete_tab
		@idea = Idea.find(params[:idea_id])
		@idea.tabs.find(params[:id]).delete
	end
	
	def reorder_tabs
		@idea = Idea.find(params[:id])
		@idea.tabs.resort!(params[:tab])
		@idea.save
		render :text => params[:tab].inspect
	end
	
	def ideas_autocomplete
	  @by_tag = if params[:term] =~ /^All(\s|\+)/
	    Tag.active.where(:name =>  Regexp.new("#{params[:term].gsub(/^All(\s|\+)/, '')}", "i")).cache.map do |tag|
	      {:label => "All #{tag.name} (#{tag.tag_type})", :value => tag.ideas.map(&:idea_num).join(", ")}
	    end
	  else  
	    []
		end
    @ideas = Idea.active.only(:name, :idea_num, :id).any_of({:idea_num => Regexp.new("^#{params[:term]}.*")}, {:name => Regexp.new("#{params[:term]}", "i")}).asc(:name).limit(20).all.map {|p| {:label => "#{p.idea_num} #{p.name}", :value => p.idea_num, :id => p.id}}
		render :json => (@by_tag + @ideas).to_json
	end
	
	def idea_helper
	  @ideas = Idea.active.only(:name, :idea_num, :images, :tag_ids).asc(:name).cache
	  @tags = Tag.active.order_by(:tag_type.asc, :name.asc).only(:tag_type).cache.group
	  @rand = rand(10**10)
	  expires_in 1.hours, 'max-stale' => 1.hours
	  render :partial => "idea_helper"
	end
	
	def idea_helper_by_tag
	  @tag = Tag.find(params[:id])
	  @ideas = @tag.ideas.cache
	  render :partial => 'idea_checkboxes'
	end
	
	def show_tabs
	  @idea = Idea.find(params[:id])
	  render :partial => "index/tab_block", :locals => {:object => @idea}
	end
	
	def clone_existing_tab
    @idea = Idea.find(params[:original_idea_id])
    @tab = @idea.tabs.build(Idea.find(params[:reusable_tab_idea_id]).tabs.find(params[:reusable_tab_id]).clone.attributes)
    @tab.save!
  rescue
    render :js => "alert('make sure both idea and tab are selected')" and return
	end
	
	def remove_product
    @idea = Idea.find(params[:id])
    @product = Product.find(params[:product_id])
    @idea.product_ids.delete @product.id
    @product.idea_ids.delete @idea.id
    @idea.save
    @product.save
    render :js => "$('li#product_#{@product.id}').remove()"
  end
  
  def add_product
    @idea = Idea.find(params[:id])
    @product = Product.find(params[:product_id])
    @idea.products << @product
    @idea.save
    render(:partial => 'product', :object => @product, :locals => {:idea_id => @idea.id})
  end
  
  def remove_tag
    @idea = Idea.find(params[:id])
    @tag = Tag.find(params[:tag_id])
    @tag.idea_ids.delete @idea.id
    @idea.tag_ids.delete @tag.id
    @tag.save
    @idea.save
    render :js => "$('li#tag_#{@tag.id}').remove()"
  end
  
  def add_tag
    @idea = Idea.find(params[:id])
    @tag = Tag.find(params[:tag_id])
    @idea.tags << @tag
    @idea.save
    render(:partial => 'tag', :object => @tag, :locals => {:idea_id => @idea.id})
  end
end
