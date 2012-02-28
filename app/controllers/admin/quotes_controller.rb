class Admin::QuotesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :update_active_status, :change_quote_name, :change_quote_date]
	before_filter :admin_user_as_permissions!, :only => [:recreate]
	
	ssl_exceptions
	
	def index
	  @current_locale = current_locale
	  criteria = Mongoid::Criteria.new(Quote)
	  criteria = criteria.where :deleted_at => nil
	  criteria = criteria.where(:user_id => params[:user_id]) unless params[:user_id].blank?
	  criteria = criteria.where :user_id.in => current_admin.users.map {|e| e.id} if current_admin.limited_sales_rep
	  criteria = criteria.active unless params[:inactive].present?
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:system.in => admin_systems)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  if params[:q].present?
	    redirect_to(admin_quote_path(:id => params[:q])) if params[:q].valid_bson_object_id?
	    regexp = params[:extended] == "1" ? Regexp.new(params[:q], "i") : Regexp.new("^#{params[:q]}")
  	  criteria = criteria.any_of({:quote_number => params[:q]}, {:name => regexp}, { 'address.first_name' => regexp}, { 'address.last_name' => regexp }, { 'address.company' => regexp }, { 'internal_comments' => regexp })
	  	@quotes = criteria.paginate :page => params[:page], :per_page => 50
	  else
  		@quotes = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50	    
	  end
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
  
  def recalculate_tax
    @quote = Quote.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@quote.user)
    raise "This quote cannot be changed" unless @quote.active_quote?
    tax_from_order(@quote)
  rescue Exception => e
    render :js => "alert('#{e}')"
  end
  
  def change_shipping
	  @quote = Quote.find(params[:id])
	  @quote.update_attributes :shipping_amount => params[:update_value][/[0-9.]+/]
	  render :inline => "$('#shipping_amount').html('<%= number_to_currency @quote.shipping_amount %>');$('#total_amount').html('<%= number_to_currency @quote.total_amount %>');<% if calculate_tax?(@quote.address.state) %>$('#tax_amount').addClass('error');alert('don\\'t forget to run CCH tax');<% end %>" # "<%= display_product_price_cart @order.shipping_amount %>"
  end
  
  def change_quote_date
    @quote = Quote.find(params[:id])
    @quote.updated_by = current_admin.email
    @quote.update_attribute :created_at, params[:update_value]
    @quote.update_attribute :expires_at, @quote.created_at + (is_ee? ? 90.days : 6.months)
    render :inline => "<%= @quote.created_at %>"
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

  def active_quotes_report
    FileUtils.mkdir "/data/shared/report_files" unless File.exists? "/data/shared/report_files"
    filename = "active_orders_report_#{current_system}_#{Time.now.utc.strftime "%m%d%Y_%H"}.csv"
    unless File.exists? "/data/shared/report_files/#{filename}"
      csv_string = CSV.generate do |csv|
        csv << ["quote_number", "quote name", "item_num", "name","release_dates", "quoted_price", "sales_price", "quantity", "campaign_name", "coupon_code", "created_at", "expires_at", "customer_rep", "company", "name", "email", "erp", "subtotal", "shipping_amount", "handling_amount", "sales_tax", "total_amount", "total_discount", ]
        Quote.send(current_system).active.each do |quote|
          quote.order_items.each do |item|
            csv << [item.quote.quote_number, item.quote.name, item.item_num, item.name, item.product.tags.release_dates.map(&:name) * ', ', item.quoted_price, item.sale_price, item.quantity, item.campaign_name,  item.quote.coupon_code, item.quote.created_at, item.quote.expires_at, item.quote.get_customer_rep.try(:email), item.quote.user.company, item.quote.user.name, item.quote.user.email, item.quote.user.erp, item.quote.subtotal_amount, item.quote.shipping_amount, item.quote.handling_amount, item.quote.tax_amount, item.quote.total_amount, item.quote.total_discount ]
          end
        end
      end
      File.open("/data/shared/report_files/#{filename}", "w") {|file| file.write(csv_string)}
    end
    send_file "/data/shared/report_files/#{filename}", :filename => filename
  end
end
