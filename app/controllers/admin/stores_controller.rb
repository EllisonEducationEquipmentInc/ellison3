class Admin::StoresController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Store)
	  criteria.where :deleted_at => nil
	  criteria = criteria.where.physical_stores if params[:physical_stores].present?
	  criteria = criteria.where.webstores if params[:webstores].present?
	  criteria.where(:brands.in => [params[:brands]]) unless params[:brands].blank?
	  criteria.where(:product_line.in => [params[:product_line]]) unless params[:product_line].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :name => regexp}, { :contact_person => regexp }, {:store_number => regexp})
	  end
		@stores = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /stores/1
  # GET /stores/1.xml
  def show
    @store = Store.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @store }
    end
  end

  # GET /stores/new
  # GET /stores/new.xml
  def new
    @store = Store.new 

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @store }
    end
  end

  # GET /stores/1/edit
  def edit
    @store = Store.find(params[:id])
  end

  # POST /stores
  # POST /stores.xml
  def create
    @store = Store.new(params[:store])

    respond_to do |format|
      if @store.save
        format.html { redirect_to(edit_admin_store_url(@store), :notice => 'Store was successfully created.') }
        format.xml  { render :xml => @store, :status => :created, :location => @store }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @store.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /stores/1
  # PUT /stores/1.xml
  def update
    @store = Store.find(params[:id])
    params[:store][:my_tag_ids] ||= []
    respond_to do |format|
      if @store.update_attributes(params[:store])
        format.html { redirect_to(admin_stores_url, :notice => 'Store was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @store.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /stores/1
  # DELETE /stores/1.xml
  def destroy
    @store = Store.find(params[:id])
    @store.destroy

    respond_to do |format|
      format.html { redirect_to(admin_stores_url) }
      format.xml  { head :ok }
    end
  end
end
