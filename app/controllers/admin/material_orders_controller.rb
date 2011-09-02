class Admin::MaterialOrdersController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :change_order_status]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(MaterialOrder)
	  criteria = criteria.where(:status => params[:status]) unless params[:status].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({'order_number' => params[:q][/\d+/].to_i}, { 'address.address1' => regexp}, { 'address.last_name' => regexp}, { 'address.company' => regexp})
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
  
  def export_to_csv
    @orders = MaterialOrder.where(:status => 'NEW', :created_at.gte => params[:start_date], :created_at.lte => params[:end_date])    
    csv_string = CSV.generate do |csv|
      csv << ["Cstmrzone", "Labelcode", "qty", "First_name", "Last_name", "Company", "Street", "Street2", "City", "State", "Zip", "Country", "Tel_num", "Email_addr"]
      @orders.each do |order|
        csv << [(UspsZone.get_zone(order.address.zip_code[0,3]).try(:zone) rescue ''), order.materials.map {|e| e.label_code} * ', ', 1, order.address.first_name.try(:upcase), order.address.last_name.try(:upcase), order.address.company.try(:upcase), order.address.address1.try(:upcase), order.address.address2.try(:upcase), order.address.city.try(:upcase), order.address.state.try(:upcase), order.address.zip_code, order.address.country.try(:upcase), order.address.phone.try(:upcase), order.address.email.try(:upcase)]
      end
    end

    # send it to the browser
    send_data csv_string,
              :type => 'text/csv; charset=iso-8859-1; header=present',
              :disposition => "attachment; filename=material_orders.csv", :x_sendfile => true
  end
end
