class Admin::ProductsController < ApplicationController
	layout 'admin'
	
	def index
		@products = Product.all.paginate :page => params[:page], :per_page => 100
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
    @product = Product.new(:start_date => I18n.localize(Time.zone.now.beginning_of_day, :format => :custom), :end_date => I18n.localize(Time.zone.now.end_of_day, :format => :custom))

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

    respond_to do |format|
      if @product.save
        format.html { redirect_to([:admin, @product], :notice => 'Product was successfully created.') }
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

    respond_to do |format|
      if @product.update_attributes(params[:product])
        format.html { redirect_to([:admin, @product], :notice => 'Product was successfully updated.') }
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
		@campaign = Campaign.new
		@campaign.product = @product
	end
	
	def create_campaign
		@product = Product.find(params[:product_id])
		@campaign = Campaign.new(params[:campaign])
		@campaign.product = @product
		render "save_campaign"
	end
	
	def delete_campaign
		@product = Product.find(params[:product_id])
		@product.campaigns.find(params[:id]).delete
	end
end
