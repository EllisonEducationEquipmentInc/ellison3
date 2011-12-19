class Admin::SubscriptionsController < ApplicationController
	layout 'admin'
	
	before_filter :set_admin_title
	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy, :upload, :fast_upload]
	
	ssl_exceptions
	
	def index
	  criteria = Mongoid::Criteria.new(Subscription)
	  criteria = criteria.where :deleted_at => nil
	  if params[:q].present?
	    regexp = Regexp.new("^#{params[:q]}")
  	  criteria = criteria.any_of({ :email => regexp}, { :name => regexp})
  		@subscriptions = criteria.paginate :page => params[:page], :per_page => 50
    else
      @subscriptions = criteria.order_by(sort_column => sort_direction).paginate :page => params[:page], :per_page => 50
	  end
	end

  # GET /subscriptions/1
  # GET /subscriptions/1.xml
  def show
    @subscription = Subscription.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @subscription }
    end
  end

  # GET /subscriptions/new
  # GET /subscriptions/new.xml
  def new
    @subscription = Subscription.new
    get_list_and_segments
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @subscription }
    end
  end

  # GET /subscriptions/1/edit
  def edit
    @subscription = Subscription.find(params[:id])
    set_current_system list_to_system(@subscription.list)
    redirect_to :action => "index" and return unless has_write_permissions?
    get_list_and_segments
  end

  # POST /subscriptions
  # POST /subscriptions.xml
  def create
    get_list_and_segments
    @subscribed = Subscription.first(:conditions => {:email => params[:subscription][:email].downcase, :list => subscription_list, :confirmed => false})
    @subscription = Subscription.new params[:subscription]
    @subscription.email = params[:subscription][:email].downcase
    @subscription.list = subscription_list
    @subscription.list_name = @list[1]
    if @subscribed.blank? && @subscription.save
      # TODO: make them delayed
      begin
        @lyris = Lyris.new :create_single_member, :email_address => @subscription.email, :list_name => @subscription.list, :full_name => @subscription.name
        @lyris = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'confirm'
        @lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @subscription.segments.map {|e| {:name => e.to_sym, :value => 1}} << {:name => :subscription_id, :value => @subscription.id.to_s} #if @subscription.segments.present?
        UserMailer.subscription_confirmation(@subscription).deliver
      rescue Exception => e
        Rails.logger.info e
        @subscription.delete
        redirect_to({:action => "new"}, :alert => "An error has occured. Please try again later, or contact customer support.") and return
      end
      redirect_to(admin_subscriptions_url, :notice => "subscription request has been successfully sent. You will receive a confirmation email shortly. Please follow its instructions to confirm your subscription.")
    else
      render :new
    end
  end

  # PUT /subscriptions/1
  # PUT /subscriptions/1.xml
  def update
    @subscription = Subscription.find(params[:id])
    get_list_and_segments
    params[:subscription][:segments] ||= []
    @subscription.write_attributes(params[:subscription])
    @lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @segments.keys.map {|e| {:name => e, :value => @subscription.segments.include?(e.to_s) ? 1 : 0}} if @segments.present?
    @subscription.save
    flash[:notice] = "Your Newsletter Subscription settings have been updated."
    redirect_to(admin_subscriptions_url)
  end
  
  def destroy
    #@lyris = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :demographics_array => @segments.keys.map {|e| {:name => e, :value => 0}} if @segments.present?
    @lyris = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => @subscription.email, :list_name => @subscription.list}, :member_status => 'unsub'
    if @lyris.success?
      @subscription.segments = []
      @subscription.destroy
      flash[:notice] = "#{@subscription.email} has been Unsubscribed from #{@subscription.list_name}."
      redirect_to(admin_subscriptions_url)
    else
      flash[:alert] = "an error has occured. please try again."
      render :subscription
    end
    redirect_to(admin_subscriptions_url)
  end
  
end
