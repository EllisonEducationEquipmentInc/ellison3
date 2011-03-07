class Admin::ProductsController < ApplicationController
	layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Product)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  criteria = criteria.where(:outlet => true) if params[:outlet] == "1"
	  criteria = criteria.where(:life_cycle => params[:life_cycle]) unless params[:life_cycle].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :item_num => regexp}, { :name => regexp }, {:short_desc => regexp})
	  end
		@products = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /products/1
  # GET /products/1.xml
  def show
    @product = Product.find(params[:id])
		@time = params[:time].blank? ? Time.zone.now : Time.zone.parse(params[:time])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @product }
    end
  end

  # GET /products/new
  # GET /products/new.xml
  def new
    @product = Product.new :"start_date_#{current_system}" => Time.zone.now.beginning_of_day, :"end_date_#{current_system}" => Time.zone.now.end_of_day

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @product }
    end
  end

  # GET /products/1/edit
  def edit
    @product = Product.find(params[:id])
  end

  # POST /products
  # POST /products.xml
  def create
    @product = Product.new(params[:product])
    @product.created_by = current_admin.email
    respond_to do |format|
      if @product.save
        format.html { redirect_to(edit_admin_product_url(@product), :notice => 'Product was successfully created.') }
        format.xml  { render :xml => @product, :status => :created, :location => @product }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @product.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /products/1
  # PUT /products/1.xml
  def update
    @product = Product.find(params[:id])
    @product.updated_by = current_admin.email
    respond_to do |format|
      if @product.update_attributes(params[:product])
        format.html { redirect_to(admin_products_url, :notice => 'Product was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @product.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /products/1
  # DELETE /products/1.xml
  def destroy
    @product = Product.find(params[:id])
    @product.destroy

    respond_to do |format|
      format.html { redirect_to(admin_products_url) }
      format.xml  { head :ok }
    end
  end


	# campaign methods
	def new_campaign
		@product = Product.find(params[:id])
		@campaign = @product.campaigns.build
	end
	
	def create_campaign
		@product = Product.find(params[:product_id])
		@campaign = @product.campaigns.build(params[:campaign])
		@campaign.created_by = current_admin.email
	end
	
	def edit_campaign
		@product = Product.find(params[:product_id])
		@campaign = @product.campaigns.find(params[:id])
	end
	
	def update_campaign
		@product = Product.find(params[:product_id])
		@campaign = @product.campaigns.find(params[:id])
		@campaign.attributes = params[:campaign]
		@campaign.updated_by = current_admin.email
	end
	
	def delete_campaign
		@product = Product.find(params[:product_id])
		@product.campaigns.find(params[:id]).delete
		@product.delay.index!
	end
	
	# image methods
	def new_image
		@product = Product.find(params[:id])
		@image = @product.images.build
	end
	
	def upload_image
		@product = Product.find(params[:product_id])
		@image = @product.images.build(params[:image])
		@image.save
	end
	
	def delete_image
		@product = Product.find(params[:product_id])
		@product.images.find(params[:id]).delete
	end
	
	# tab methods
	def new_tab
		@product = Product.find(params[:id])
		@tab = @product.tabs.build
	end
	
	def reusable_tab
		@product = Product.find(params[:id])
	end
	
	def create_tab
		@product = Product.find(params[:product_id])
		@tab = @product.tabs.build(params[:tab])
		@tab.created_by = current_admin.email
	end
	
	def edit_tab
		@product = Product.find(params[:product_id])
		@tab = @product.tabs.find(params[:id])
	end
	
	def update_tab
		@product = Product.find(params[:product_id])
		@tab = @product.tabs.find(params[:id])
		@tab.write_attributes params[:tab]
		@tab.updated_by = current_admin.email
		@tab.save
	end
	
	def delete_tab
		@product = Product.find(params[:product_id])
		@product.tabs.find(params[:id]).delete
	end
	
	def reorder_tabs
		@product = Product.find(params[:id])
		@product.tabs.resort!(params[:tab])
		@product.save
		render :text => params[:tab].inspect
	end
	
	def products_autocomplete
	  @by_tag = if params[:term] =~ /^All(\s|\+)/
	    Tag.active.where(:name =>  Regexp.new("#{params[:term].gsub(/^All(\s|\+)/, '')}", "i")).cache.map do |tag|
	      {:label => "All #{tag.name} (#{tag.tag_type})", :value => tag.products.map(&:item_num).join(", ")}
	    end
	  else  
	    []
		end
    @products = Product.active.only(:name, :item_num, :id, :"msrp_#{current_currency}").any_of({:item_num => Regexp.new("^#{params[:term]}.*")}, {:name => Regexp.new("#{params[:term]}", "i")}).asc(:name).limit(20).all.map {|p| {:label => "#{p.item_num} #{p.name}", :value => p.item_num, :id => p.id, :msrp => p.msrp}}
		render :json => (@by_tag + @products).to_json
	end
	
	def product_helper
	  @products = Product.active.only(:name, :item_num, :images, :tag_ids).asc(:name).cache
	  @tags = Tag.active.order_by(:tag_type.asc, :name.asc).only(:tag_type).cache.group
	  @rand = rand(10**10)
	  expires_in 1.hours, 'max-stale' => 1.hours
	  render :partial => "product_helper"
	end
	
	def product_helper_by_tag
	  @tag = Tag.find(params[:id])
	  @products = @tag.products.cache
	  render :partial => 'product_checkboxes'
	end
	
	def show_tabs
	  @product = Product.find(params[:id])
	  render :partial => "index/tab_block", :locals => {:object => @product}
	end
	
	def clone_existing_tab
    @product = Product.find(params[:original_product_id])
    @tab = @product.tabs.build(Product.find(params[:reusable_tab_product_id]).tabs.find(params[:reusable_tab_id]).clone.attributes)
    @tab.save!
  rescue
    render :js => "alert('make sure both product and tab are selected')" and return
	end

	def remove_idea
    @idea = Idea.find(params[:idea_id])
    @product = Product.find(params[:id])
    @idea.product_ids.delete @product.id
    @product.idea_ids.delete @idea.id
    @idea.save(:validate => false)
    @product.save(:validate => false)
    render :js => "$('li#idea_#{@idea.id}').remove()"
  end
  
  def add_idea
    @idea = Idea.find(params[:idea_id])
    @product = Product.find(params[:id])
    @product.ideas << @idea
    @product.save(:validate => false)
    render(:partial => 'idea', :object => @idea, :locals => {:product_id => @product.id})
  end
  
  def remove_tag
    @product = Product.find(params[:id])
    @tag = Tag.find(params[:tag_id])
    @tag.product_ids.delete @product.id
    @product.tag_ids.delete @tag.id
    @tag.save(:validate => false)
    @product.save(:validate => false)
    render :js => "$('li#tag_#{@tag.id}').remove()"
  end
  
  def add_tag
    @product = Product.find(params[:id])
    @tag = Tag.find(params[:tag_id])
    @product.tags << @tag
    @product.save(:validate => false)
    @product.index_by_tag @tag
    render(:partial => 'tag', :object => @tag, :locals => {:product_id => @product.id})
  end
end
