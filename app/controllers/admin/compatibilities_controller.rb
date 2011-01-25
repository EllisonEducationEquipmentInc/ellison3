class Admin::CompatibilitiesController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Tag)
	  criteria = criteria.product_lines
	  criteria.where :deleted_at => nil
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria.any_of({ :name => regexp}, { 'compatibilities.products'.in => [regexp] })
	  end
		@compatibilities = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end


  # GET /compatibilities/1/edit
  def edit
    @compatibility = Tag.find(params[:id])
  end

  # PUT /compatibilities/1
  # PUT /compatibilities/1.xml
  def update
    @compatibility = Tag.find(params[:id])
    respond_to do |format|
      if @compatibility.update_attributes(params[:compatibility])
        format.html { redirect_to(admin_compatibilities_url, :notice => 'Tag was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @compatibility.errors, :status => :unprocessable_entity }
      end
    end
  end

end
