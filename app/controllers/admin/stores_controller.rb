class Admin::StoresController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]

  ssl_exceptions

  def index
    criteria = get_criteria_for_stores(params)
    @stores = criteria.order_by(sort_column => sort_direction).page(params[:page]).per(50)
  end

  def new
    @store = Store.new :country => 'United States'
  end

  def edit
    @store = Store.find(params[:id])
  end

  def create
    @store = Store.new(params[:store])
    @store.created_by = current_admin.email
    if @store.save
      redirect_to(edit_admin_store_url(@store), :notice => 'Store was successfully created.')
    else
      render :new
    end
  end

  def update
    @store = Store.find(params[:id])
    @store.updated_by = current_admin.email
    if @store.update_attributes(params[:store])
      redirect_to(admin_stores_url, :notice => 'Store was successfully updated.')
    else
      render :edit
    end
  end

  def destroy
    @store = Store.find(params[:id])
    @store.destroy
    redirect_to(admin_stores_url)
  end

  private

  def get_criteria_for_stores params
    criteria = Mongoid::Criteria.new(Store)
    criteria = criteria.where :deleted_at => nil
    criteria = criteria.where.physical_stores if params[:physical_stores].present?
    criteria = criteria.where.webstores if params[:webstores].present?
    criteria = criteria.where.catalog_companies if params[:catalog_company].present?
    criteria = criteria.where(:active => true) if params[:inactive].blank?
    criteria = criteria.where(:brands.in => [params[:brands]]) unless params[:brands].blank?
    criteria = criteria.where(:product_line.in => [params[:product_line]]) unless params[:product_line].blank?
    criteria = criteria.where(:systems_enabled.in => params[:sites_enabled]) unless params[:sites_enabled].blank?
    criteria = criteria.where(:agent_type.in => [params[:agent_type]]) unless params[:agent_type].blank?

    unless params[:q].blank?
      regexp = Regexp.new(params[:q], "i")
      criteria = criteria.any_of({ :name => regexp}, { :contact_person => regexp }, {:store_number => regexp}, {:zip_code =>regexp})
    end

    criteria
  end
end
