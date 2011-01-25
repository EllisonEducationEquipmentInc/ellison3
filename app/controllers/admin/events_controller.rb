class Admin::EventsController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Event)
	  criteria = criteria.where :deleted_at => nil
	  criteria = if params[:systems_enabled].blank?
	    criteria.where(:systems_enabled.in => admin_systems)
	  else
	    criteria.where(:systems_enabled.in => params[:systems_enabled]) 
	  end
	  criteria = criteria.where(:active => true) if params[:inactive].blank?
	  unless params[:q].blank?
	    regexp = Regexp.new(params[:q], "i")
  	  criteria = criteria.any_of({ :name => regexp}, { :event_number => regexp }, {:keywords => regexp})
	  end
		@events = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	end

  # GET /events/1
  # GET /events/1.xml
  def show
    @event = Event.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/new
  # GET /events/new.xml
  def new
    @event = Event.new 

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @event }
    end
  end

  # GET /events/1/edit
  def edit
    @event = Event.find(params[:id])
  end

  # POST /events
  # POST /events.xml
  def create
    @event = Event.new(params[:event])

    respond_to do |format|
      if @event.save
        format.html { redirect_to(edit_admin_event_url(@event), :notice => 'Event was successfully created.') }
        format.xml  { render :xml => @event, :status => :created, :location => @event }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /events/1
  # PUT /events/1.xml
  def update
    @event = Event.find(params[:id])
    respond_to do |format|
      if @event.update_attributes(params[:event])
        format.html { redirect_to(admin_events_url, :notice => 'Event was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @event.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /events/1
  # DELETE /events/1.xml
  def destroy
    @event = Event.find(params[:id])
    @event.destroy

    respond_to do |format|
      format.html { redirect_to(admin_events_url) }
      format.xml  { head :ok }
    end
  end
end
