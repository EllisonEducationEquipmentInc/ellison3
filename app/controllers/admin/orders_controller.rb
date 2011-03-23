class Admin::OrdersController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :authorize_cc, :change_order_status, :recalculate_tax, :change_amount, :make_payment]
	before_filter :admin_user_as_permissions!, :only => [:recreate]
	
	ssl_exceptions
	
	def index
	  @current_locale = current_locale
	  criteria = Mongoid::Criteria.new(Order)
	  criteria = criteria.where :deleted_at => nil
	  criteria = criteria.where :user_id.in => current_admin.users.map {|e| e.id} if current_admin.limited_sales_rep
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:system.in => admin_systems)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:status => params[:status]) unless params[:status].blank?
	  criteria = criteria.where('payment.deferred' => Boolean.set(params[:deferred])) unless params[:deferred].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({'order_number' => params[:q][/\d+/].to_i}, {'address.email' => regexp},  {'address.first_name' => regexp}, { 'address.last_name' => regexp }, { 'address.city' => regexp }, { 'address.address' => regexp })
	  end
	  order = params[:sort] ? {sort_column => sort_direction} : [[:created_at, :desc]]
		@orders = criteria.order_by(order).paginate :page => params[:page], :per_page => 50
	end

  # GET /orders/1
  # GET /orders/1.xml
  def show
    @current_locale = current_locale
    @order = Order.find(params[:id])
    new_payment(@order.user) if @order.can_be_paid?
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @order }
    end
  end

  # GET /orders/new
  # GET /orders/new.xml
  def new
    @order = Order.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @order }
    end
  end

  # GET /orders/1/edit
  def edit
    @order = Order.find(params[:id])
  end


  # PUT /orders/1
  # PUT /orders/1.xml
  def update
    @order = Order.find(params[:id])
    respond_to do |format|
      if @order.update_attributes(params[:order])
        format.html { redirect_to(admin_orders_url, :notice => 'Order was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @order.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def update_internal_comment
    @order = Order.find(params[:id])
    @order.update_attributes :internal_comments => params[:update_value]
    render :text => @order.internal_comments
  end
  
  def update_estimated_ship_date
    @order = Order.find(params[:id])
    @order.update_attribute :estimated_ship_date, params[:update_value]
    render :text => @order.estimated_ship_date
  rescue Exception => e
    render :text => e
  end
  
  def change_order_status
    @order = Order.find(params[:id])
    @order.send "#{params[:update_value].parameterize.underscore}!"
    @order.save
    render :text => @order.status
  rescue Exception => e
    render :text => e
  end
  
  def authorize_cc
    @current_locale = current_locale
    @order = Order.find(params[:id])
    change_current_system @order.system
    @order.payment.use_saved_credit_card = true
    I18n.locale = @order.locale
    raise "This order cannot be changed" if @order.status_frozen?
    process_card(:amount => (@order.total_amount * 100).round, :payment => @order.payment, :order => @order.id.to_s, :capture => true, :use_payment_token => true, :system => @order.system)
    @order.open!
    @order.save
    flash[:notice] = "Successful transaction..."
  rescue Exception => e
    # TODO: UserNotifier.deliver_declined_cc(@order, e.to_s.gsub(/^.+\<br\>\<br\>\s/, '').gsub("<br>", "\n")) if is_ee_us? && e.to_s.include?("could not be authorized")
    flash[:alert] = e #exp_msg(e)
  ensure
    I18n.locale = @current_locale
    redirect_to admin_order_path(@order)
  end
  
  def recalculate_tax
    @order = Order.find(params[:id])
    raise "This order cannot be changed" if @order.status_frozen?
    tax_from_order(@order)
  rescue Exception => e
    render :js => "alert('#{e}')"
  end
  
  def change_shipping
	  @order = Order.find(params[:id])
	  @order.update_attributes :shipping_amount => params[:update_value][/[0-9.]+/]
	  render :inline => "$('#shipping_amount').html('<%= number_to_currency @order.shipping_amount %>');$('#total_amount').html('<%= number_to_currency @order.total_amount %>');<% if calculate_tax?(@order.address.state) %>$('#tax_amount').addClass('error');alert('don\\'t forget to run CCH tax');<% end %>" # "<%= display_product_price_cart @order.shipping_amount %>"
  end
  
  def recreate
    @order = Order.find(params[:id])
    change_current_system @order.system
    I18n.locale = @order.locale
    sign_in("user", @order.user)
    clear_cart
    order_to_cart @order
		unless @order.status_frozen?
    	@order.cancelled!
    	#@order.save 
    	get_cart.update_attributes :order_reference => @order.id
		end
    redirect_to checkout_path
  end
  
  def make_payment
    @current_locale = current_locale
    @order = Order.find(params[:order][:id])
    change_current_system @order.system
    I18n.locale = @order.locale
    @order.payment = Payment.new(params[:order][:payment])
    process_card(:amount => (@order.total_amount * 100).round, :payment => @order.payment, :order => @order.id.to_s, :capture => true, :use_payment_token => false, :system => @order.system)
    @order.off_hold!
    @order.save
    @order.decrement_items! 
	  @order.user.add_to_owns_list @order.order_items.map {|e| e.product_id}
    flash[:notice] = "Successful transaction..."
    render :js => "window.location.href = '#{admin_orders_path}'" and return
  rescue Exception => e
    @error_message = e.to_s #exp_msg(e)
  end
end
