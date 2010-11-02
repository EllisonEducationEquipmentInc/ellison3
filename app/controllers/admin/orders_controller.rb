class Admin::OrdersController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :update_internal_comment, :authorize_cc, :change_order_status]
	
	ssl_exceptions
	
	def index
	  @current_locale = current_locale
	  criteria = Mongoid::Criteria.new(Order)
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
		@orders = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /orders/1
  # GET /orders/1.xml
  def show
    @current_locale = current_locale
    @order = Order.find(params[:id])
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

  # DELETE /orders/1
  # DELETE /orders/1.xml
  def destroy
    @order = Order.find(params[:id])
    @order.destroy

    respond_to do |format|
      format.html { redirect_to(admin_orders_url) }
      format.xml  { head :ok }
    end
  end
  
  def update_internal_comment
    @order = Order.find(params[:id])
    @order.update_attributes :internal_comments => params[:update_value]
    render :text => @order.internal_comments
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
    @order = Order.find(params[:id])
    @order.payment.use_saved_credit_card = true
    I18n.locale = @order.locale
    begin
      raise "This order cannot be changed" if @order.status_frozen?
      process_card(:amount => (@order.total_amount * 100).round, :payment => @order.payment, :order => @order.id.to_s, :capture => true, :use_payment_token => true)
      @order.open!
      @order.save
      flash[:notice] = "Successful transaction..."
    rescue Exception => e
      #UserNotifier.deliver_declined_cc(@order, e.to_s.gsub(/^.+\<br\>\<br\>\s/, '').gsub("<br>", "\n")) if is_ee_us? && e.to_s.include?("could not be authorized")
      flash[:alert] = e #exp_msg(e)
    end
    I18n.locale = @locale
    redirect_to admin_order_path(@order)
  end
end
