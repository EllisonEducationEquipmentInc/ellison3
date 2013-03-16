class Admin::DiscountCategoriesController < ApplicationController
  layout 'admin'
	
	before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	#verify :method => :post, :only => [:update]
	
	def index
	  @discount_categories = DiscountCategory.active.asc(:created_at)
	end
	
	def update
	  attribute, id = params[:element_id].split("-")
	  @discount_category = DiscountCategory.find  id
	  @discount_category.send("#{attribute}=", params[:update_value])
	  @discount_category.save!
	  render :text => params[:update_value]
	rescue Exception => e
	  render :text => e, :status => 500
	end
end
