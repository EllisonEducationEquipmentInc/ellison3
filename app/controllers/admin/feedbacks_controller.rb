class Admin::FeedbacksController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :show, :edit, :update, :destroy, :update_attribute, :add_comment]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Feedback)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:system.in => admin_systems)
	  else
	    criteria.where(:system.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:status => params[:status]) unless params[:status].blank?
	  criteria = criteria.where(:department => params[:department]) unless params[:department].blank?
	  criteria = criteria.where(:subject => params[:subject]) unless params[:subject].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :email => regexp}, { 'comments.message' => regexp }, {:number => params[:q]})
	  end
	  order = params[:sort] ? {sort_column => sort_direction} : [[:status, :asc], [:created_at, :desc]]
		@feedbacks = criteria.order_by(order).paginate :page => params[:page], :per_page => 50
	end

  # GET /feedbacks/1
  # GET /feedbacks/1.xml
  def show
    @feedback = Feedback.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @feedback }
    end
  end

  # GET /feedbacks/new
  # GET /feedbacks/new.xml
  def new
    @feedback = Feedback.new 

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @feedback }
    end
  end

  # GET /feedbacks/1/edit
  def edit
    @feedback = Feedback.find(params[:id])
  end

  # POST /feedbacks
  # POST /feedbacks.xml
  def create
    @feedback = Feedback.new(params[:feedback])

    respond_to do |format|
      if @feedback.save
        format.html { redirect_to(edit_admin_feedback_url(@feedback), :notice => 'Feedback was successfully created.') }
        format.xml  { render :xml => @feedback, :status => :created, :location => @feedback }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @feedback.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /feedbacks/1
  # PUT /feedbacks/1.xml
  def update
    @feedback = Feedback.find(params[:id])
    params[:feedback][:my_tag_ids] ||= []
    respond_to do |format|
      if @feedback.update_attributes(params[:feedback])
        format.html { redirect_to(admin_feedbacks_url, :notice => 'Feedback was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @feedback.errors, :status => :unprocessable_entity }
      end
    end
  end
  
  def update_attribute
    attribute, id = params[:element_id].split("_")
    @feedback = Feedback.find(id)
    @feedback.update_attribute attribute, params[:update_value]
    render :text => params[:update_value]
  end
  
  def add_comment
	  @feedback = Feedback.find(params[:id])
	  @comment = @feedback.comments.build params[:comment]
	  @comment.admin_reply = true
	  @feedback.status = "replied"
	  respond_to do |format|
      if @feedback.save
        change_current_system @feedback.system
        UserMailer.delay.feedback_reply(@feedback)
        format.html { redirect_to(admin_feedbacks_url, :notice => 'Your reply was sent') }
        format.xml  { render :xml => @feedback, :status => :created, :location => @feedback }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @feedback.errors, :status => :unprocessable_entity }
      end
    end
	end

  # DELETE /feedbacks/1
  # DELETE /feedbacks/1.xml
  def destroy
    @feedback = Feedback.find(params[:id])
    @feedback.destroy

    respond_to do |format|
      format.html { redirect_to(admin_feedbacks_url) }
      format.xml  { head :ok }
    end
  end
end
