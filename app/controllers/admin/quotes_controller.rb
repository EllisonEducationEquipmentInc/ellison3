class Admin::QuotesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :update_active_status]
	before_filter :admin_user_as_permissions!, :only => [:recreate]
	
	ssl_exceptions
	
	def index
	  @current_locale = current_locale
	  criteria = Mongoid::Criteria.new(Quote)
	  criteria.where :deleted_at => nil
	  if params[:systems_enabled].blank?
	    criteria.where(:system.in => admin_systems)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  criteria.where(:status => params[:status]) unless params[:status].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ 'address.first_name' => regexp}, { 'address.last_name' => regexp }, { 'address.city' => regexp }, { 'address.address' => regexp })
	  end
		@quotes = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /quotes/1
  # GET /quotes/1.xml
  def show
    @current_locale = current_locale
    @quote = Quote.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @quote }
    end
  end

  # GET /quotes/new
  # GET /quotes/new.xml
  def new
    @quote = Quote.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @quote }
    end
  end

  # GET /quotes/1/edit
  def edit
    @quote = Quote.find(params[:id])
  end


  # PUT /quotes/1
  # PUT /quotes/1.xml
  def update
    @quote = Quote.find(params[:id])
    respond_to do |format|
      if @quote.update_attributes(params[:quote])
        format.html { redirect_to(admin_quotes_url, :notice => 'Quote was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @quote.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /quotes/1
  # DELETE /quotes/1.xml
  def destroy
    @quote = Quote.find(params[:id])
    @quote.destroy

    respond_to do |format|
      format.html { redirect_to(admin_quotes_url) }
      format.xml  { head :ok }
    end
  end
  
  def update_internal_comment
    @quote = Quote.find(params[:id])
    @quote.update_attributes :internal_comments => params[:update_value]
    render :text => @quote.internal_comments
  end
  
  def update_active_status
    @quote = Quote.find(params[:id])
    @quote.update_attributes :active => params[:active]
    render :nothing => true
  end
  
  def recreate
    @quote = Quote.find(params[:id])
    change_current_system @quote.system
    I18n.locale = @quote.locale
    sign_in("user", @quote.user)
    get_cart.clear
    order_to_cart @quote
    @quote.update_attributes :active => false
    redirect_to checkout_path
  end
end
