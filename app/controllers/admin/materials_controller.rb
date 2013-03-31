class Admin::MaterialsController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
  
  ssl_exceptions
  
  def index
    criteria = Mongoid::Criteria.new(Material)
    criteria = criteria.where :deleted_at => nil
    criteria = criteria.where(:active => true) if params[:inactive].blank?
    unless params[:q].blank?
      regexp = Regexp.new(params[:q], "i")
      criteria = criteria.where({ :name => regexp})
    end
    @materials = criteria.order_by(sort_column => sort_direction).page(params[:page]).per(50)
  end

  # GET /materials/1
  # GET /materials/1.xml
  def show
    @material = Material.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @material }
    end
  end

  # GET /materials/new
  # GET /materials/new.xml
  def new
    @material = Material.new 
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @material }
    end
  end

  # GET /materials/1/edit
  def edit
    @material = Material.find(params[:id])
  end

  # POST /materials
  # POST /materials.xml
  def create
    @material = Material.new(params[:material])

    respond_to do |format|
      if @material.save
        format.html { redirect_to(admin_materials_url, :notice => 'Material was successfully created.') }
        format.xml  { render :xml => @material, :status => :created, :location => @material }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @material.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /materials/1
  # PUT /materials/1.xml
  def update
    @material = Material.find(params[:id])
    respond_to do |format|
      if @material.update_attributes(params[:material])
        format.html { redirect_to(admin_materials_url, :notice => 'Material was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @material.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /materials/1
  # DELETE /materials/1.xml
  def destroy
    @material = Material.find(params[:id])
    @material.destroy

    respond_to do |format|
      format.html { redirect_to(admin_materials_url) }
      format.xml  { head :ok }
    end
  end
end
