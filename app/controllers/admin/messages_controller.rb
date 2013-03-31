class Admin::MessagesController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
  
  ssl_exceptions
  
  def index
    criteria = Mongoid::Criteria.new(Message)
    criteria = criteria.where :deleted_at => nil
    criteria = criteria.where(:active => true) if params[:inactive].blank?
    if params[:user_id].present? && params[:user_id].valid_bson_object_id?
      criteria = criteria.where(:user_id => params[:user_id])
    else
      criteria = criteria.where(:discount_level.in => [params[:discount_level]]) unless params[:discount_level].blank?
      criteria = criteria.group_message
    end
    
    unless params[:q].blank?
      regexp = Regexp.new(params[:q], "i")
      criteria = criteria.any_of({ :subject => regexp})
    end
    @messages = criteria.order_by(sort_column => sort_direction).page(params[:page]).per(50)
  end
  

  # GET /messages/1
  # GET /messages/1.xml
  def show
    @message = Message.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @message }
    end
  end

  # GET /messages/new
  # GET /messages/new.xml
  def new
    @message = Message.new
    @message.user_id = params[:user_id] if params[:user_id].present? && params[:user_id].valid_bson_object_id?
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @message }
    end
  end

  # GET /messages/1/edit
  def edit
    @message = Message.find(params[:id])
  end

  # POST /messages
  # POST /messages.xml
  def create
    @message = Message.new(params[:message])
    respond_to do |format|
      if @message.save
        format.html { redirect_to(admin_messages_url(:user_id => @message.user_id), :notice => 'Message was successfully created.') }
        format.xml  { render :xml => @message, :status => :created, :location => @message }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /messages/1
  # PUT /messages/1.xml
  def update
    @message = Message.find(params[:id])
    respond_to do |format|
      if @message.update_attributes(params[:message])
        format.html { redirect_to(admin_messages_url(:user_id => @message.user_id), :notice => 'Message was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /messages/1
  # DELETE /messages/1.xml
  def destroy
    @message = Message.find(params[:id])
    @message.destroy
    respond_to do |format|
      format.html { redirect_to(admin_messages_url) }
      format.xml  { head :ok }
    end
  end
end
