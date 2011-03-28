class Admin::QuotesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :update_active_status, :change_quote_name]
	before_filter :admin_user_as_permissions!, :only => [:recreate]
	
	ssl_exceptions
	
	def index
	  @current_locale = current_locale
	  criteria = Mongoid::Criteria.new(Quote)
	  criteria = criteria.where :deleted_at => nil
	  criteria = criteria.where(:user_id => params[:user_id]) unless params[:user_id].blank?
	  criteria = criteria.where :user_id.in => current_admin.users.map {|e| e.id} if current_admin.limited_sales_rep
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:system.in => admin_systems)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:status => params[:status]) unless params[:status].blank?
	  unless params[:q].blank?
	    redirect_to(admin_quote_path(:id => params[:q])) if params[:q].valid_bson_object_id?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({:name => regexp}, { 'address.first_name' => regexp}, { 'address.last_name' => regexp }, { 'address.company' => regexp }, { 'internal_comments' => regexp })
	  end
		@quotes = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /quotes/1
  # GET /quotes/1.xml
  def show
    @current_locale = current_locale
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
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
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
  end


  # PUT /quotes/1
  # PUT /quotes/1.xml
  def update
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    @quote.updated_by = current_admin.email
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
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    @quote.destroy

    respond_to do |format|
      format.html { redirect_to(admin_quotes_url) }
      format.xml  { head :ok }
    end
  end
  
  def update_internal_comment
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    @quote.updated_by = current_admin.email
    @quote.update_attributes :internal_comments => params[:update_value]
    render :text => @quote.internal_comments
  end
  
  def update_active_status
    @quote = Quote.find(params[:id])
    @quote.updated_by = current_admin.email
    @quote.update_attributes :active => params[:active]
    render :nothing => true
  end
  
  def change_quote_name
    @quote = Quote.find(params[:element_id])
    @quote.updated_by = current_admin.email
    @quote.update_attribute :name, params[:update_value]
    render :text => @quote.name
  end
  
  def recreate
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    change_current_system @quote.system
    I18n.locale = @quote.locale
    sign_in("user", @quote.user)
    clear_cart
    order_to_cart @quote
    @quote.updated_by = current_admin.email
    @quote.update_attributes :active => false
    redirect_to cart_path
  end
  
  def login_as_and_goto_quote
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if !@quote.active_quote? || current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    change_current_system @quote.system
    I18n.locale = @quote.locale
    sign_in("user", @quote.user)
    redirect_to myquote_path(@quote)
  end
  
  def pre_orders_report
    FileUtils.mkdir "/data/shared/report_files" unless File.exists? "/data/shared/report_files"
    filename = "pre_orders_report_#{current_system}_#{Time.now.utc.strftime "%m%d%Y_%H"}.csv"
	  unless File.exists? "/data/shared/report_files/#{filename}"
	    csv_string = CSV.generate do |csv|
        csv << ["item_num", "quantity", "item_total"]
        Quote.pre_orders_report.each do |item|
          csv << [item["_id"], item["value"]["quantity"], item["value"]["item_total"]]
        end
      end
	    File.open("/data/shared/report_files/#{filename}", "w") {|file| file.write(csv_string)}
	  end
	  send_file "/data/shared/report_files/#{filename}", :filename => filename
	end
end
