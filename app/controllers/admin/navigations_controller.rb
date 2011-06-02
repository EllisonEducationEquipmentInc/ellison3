class Admin::NavigationsController < ApplicationController
	layout 'admin'

  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!
	
	ssl_exceptions
	
	def index
	  @top_navigations = TopNavigation.instance.list
	end
	
	def create
	  @navigation = Navigation.new(params[:navigation])
	  render :save
	end
	
	def update
	  @navigation = Navigation.find(params[:id])
    @navigation.attributes = params[:navigation]
	  render :save
	end
	
	def destroy
	  @navigation = Navigation.find(params[:id])
    @navigation.destroy
    @navigation = Navigation.find_or_initialize_by(:system => current_system, :top_nav => @navigation.top_nav, :column => @navigation.column)
	end
end
