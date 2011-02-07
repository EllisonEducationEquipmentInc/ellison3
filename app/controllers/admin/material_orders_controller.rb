class Admin::MaterialOrdersController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(MaterialOrder)
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.where({'order_number' => params[:q][/\d+/].to_i}, { 'address.address1' => regexp})
	  end
		@material_orders = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /material_orders/1
  # GET /material_orders/1.xml
  def show
    @material_order = MaterialOrder.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @material_order }
    end
  end
  
  def change_order_status
    @material_order = MaterialOrder.find(params[:element_id])
    @material_order.status = params[:update_value]
    @material_order.shipped_at = Time.zone.now if params[:update_value] == "SHIPPED"
    @material_order.save
    render :text => @material_order.status
  rescue Exception => e
    render :text => e
  end
end
