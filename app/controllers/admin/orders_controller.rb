class Admin::OrdersController < ApplicationController
  layout 'admin'
  
  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :authorize_cc, :change_order_status, :recalculate_tax, :change_amount, :make_payment, :refund_cc]
  before_filter :admin_user_as_permissions!, :only => [:recreate]
  
  ssl_exceptions
  
  def index
    @current_locale = current_locale
    criteria = Mongoid::Criteria.new(Order)
    criteria = criteria.where :deleted_at => nil
    criteria = criteria.where(:user_id => params[:user_id]) unless params[:user_id].blank?
    criteria = criteria.where :user_id.in => current_admin.users.map {|e| e.id} if current_admin.limited_sales_rep
    criteria = if params[:systems_enabled].blank?
      criteria.where(:system.in => admin_systems)
    else
      criteria.where(:system.in => params[:systems_enabled]) 
    end
    criteria = criteria.where(:status => params[:status]) unless params[:status].blank?
    criteria = criteria.where('payment.deferred' => Boolean.set(params[:deferred])) unless params[:deferred].blank?
    criteria = criteria.where('gift_card.vendor_tx_code' => params[:identifier]) unless params[:identifier].blank?
    criteria = criteria.where('order_items.gift_card' => Boolean.set(params[:gift_card])) unless params[:gift_card].blank?
    criteria = criteria.where(:gift_card.exists => Boolean.set(params[:paid_with_gift_card])) unless params[:paid_with_gift_card].blank?
    if params[:q].present?
      regexp = params[:extended] == "1" ? Regexp.new(params[:q], "i") : Regexp.new("^#{params[:q]}")
      criteria = criteria.where({'order_number' => params[:q][/\d+/].to_i} )
      @orders = criteria.page(params[:page]).per(50)
    elsif params[:others].present?
      regexp = params[:extended] == "1" ? Regexp.new(params[:others], "i") : Regexp.new("^#{params[:others]}")
      criteria = criteria.any_of({'address.email' => regexp}, {'address.company' => regexp}, { 'address.last_name' => regexp })
      @orders = criteria.page(params[:page]).per(50)
    else
      order = params[:order] ? {sort_column => sort_direction} : [[:created_at, :desc]]
      @orders = criteria.order_by(order).page(params[:page]).per(50)
    end
  end

  # GET /orders/1
  # GET /orders/1.xml
  def show
    @current_locale = current_locale
    @order = Order.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
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
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
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
    @order = Order.find(params[:id] || params[:element_id])
    if @order.uk_may_change? || !@order.status_frozen? || @order.to_refund?
      @order.send "#{params[:update_value].parameterize.underscore}!"
      @order.refund_gc! if @order.system == "eeus" && (@order.status_change == ["New", "Cancelled"] || @order.status_change == ["Pending", "Cancelled"])
      @order.save
    end
    render :text => @order.status
  rescue Exception => e
    render :text => e
  end
  
  def authorize_cc
    @current_locale = current_locale
    @order = Order.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
    change_current_system @order.system
    @order.payment.use_saved_credit_card = true
    I18n.locale = @order.locale
    raise "This order cannot be changed" if @order.status_frozen?
    process_card(:amount => (@order.balance_due * 100).round, :payment => @order.payment, :order => @order.id.to_s, :capture => is_uk?, :use_payment_token => true, :system => @order.system)
    @order.open!
    @order.save
    flash[:notice] = "Successful transaction..."
  rescue Exception => e
    # TODO: UserNotifier.deliver_declined_cc(@order, e.to_s.gsub(/^.+\<br\>\<br\>\s/, '').gsub("<br>", "\n")) if is_ee_us? && e.to_s.include?("could not be authorized")
    flash[:alert] = e.to_s.html_safe #exp_msg(e)
  ensure
    I18n.locale = @current_locale
    redirect_to admin_order_path(@order)
  end
  
  def recalculate_tax
    @order = Order.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
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
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
    sign_in_and_populate_cart
    unless @order.status_frozen?
      @order.cancelled!
      flash[:alert] = "Gift Card Voided" if @order.gc_needs_refund?
      @order.refund_gc!
      flash[:alert] = "Gift Card Void failed. Please contact accounting to credit GC." if @order.gc_needs_refund?
      @order.save
      get_cart.update_attributes :order_reference => @order.id
    end
    redirect_to cart_path
  end
  
  def make_payment
    @current_locale = current_locale
    @order = Order.find(params[:order][:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
    change_current_system @order.system
    I18n.locale = @order.locale
    @order.payment = Payment.new(params[:order][:payment])
    process_card(:amount => (@order.balance_due * 100).round, :payment => @order.payment, :order => @order.id.to_s, :capture => is_uk?, :use_payment_token => false, :system => @order.system)
    @order.off_hold!
    @order.save
    @order.decrement_items! 
    @order.user.add_to_owns_list @order.order_items.map {|e| e.product_id}
    flash[:notice] = "Successful transaction..."
    render :js => "window.location.href = '#{admin_orders_path}'" and return
  rescue Exception => e
    @error_message = e.to_s #exp_msg(e)
  end
  
  def refund_cc
    @order = Order.find(params[:id])
    redirect_to :action => "index" and return if current_admin.limited_sales_rep && !current_admin.users.include?(@order.user)
    change_current_system @order.system
    @order.refund_gc!
    flash[:alert] = "Gift Card Void failed. Please try again" if @order.gc_needs_refund?
    net_response = refund_cc_transaction(@order.payment) if @order.payment
    unless @order.payment_needs_refund? || @order.gc_needs_refund?
      @order.refunded!
      @order.save
      tax_from_order(@order, true) if @order.tax_committed #CCH 'return'
      if params[:recreate]
        sign_in_and_populate_cart
        get_cart.update_attributes :order_reference => @order.id
        redirect_to cart_path, :notice => net_response && net_response.message || "successful transaction" and return
      end
    end
    redirect_to(admin_order_path(@order), :notice => net_response && net_response.message || "successful transaction")
  rescue Exception => e
    redirect_to(admin_order_path(@order), :alert => e.to_s)
  end

private

  def sign_in_and_populate_cart
    change_current_system @order.system
    I18n.locale = @order.locale
    sign_out(current_user) if user_signed_in?
    clear_cart
    get_cart.save
    sign_in("user", @order.user)
    order_to_cart @order
  end
end
