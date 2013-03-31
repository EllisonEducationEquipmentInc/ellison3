class Admin::SearchPhrasesController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
  before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!, :only => [:new, :create, :edit, :update, :destroy]
  
  ssl_exceptions
  
  def index
    criteria = Mongoid::Criteria.new(SearchPhrase)
    criteria = criteria.where :deleted_at => nil
    criteria = if params[:systems_enabled].blank?
      criteria.where(:systems_enabled.in => admin_systems)
    else
      criteria.where(:systems_enabled.in => params[:systems_enabled]) 
    end
    criteria = criteria.where(:active => true) if params[:inactive].blank?
    unless params[:q].blank?
      regexp = Regexp.new(params[:q], "i")
      criteria = criteria.any_of({ :phrase => regexp}, { :destination => regexp})
    end
    @search_phrases = criteria.order_by(sort_column => sort_direction).page(params[:page]).per(100)
  end

  # GET /search_phrases/1
  # GET /search_phrases/1.xml
  def show
    @search_phrase = SearchPhrase.find(params[:id])
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @search_phrase }
    end
  end

  # GET /search_phrases/new
  # GET /search_phrases/new.xml
  def new
    @search_phrase = SearchPhrase.new
    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @search_phrase }
    end
  end

  # GET /search_phrases/1/edit
  def edit
    @search_phrase = SearchPhrase.find(params[:id])
  end

  # POST /search_phrases
  # POST /search_phrases.xml
  def create
    @search_phrase = SearchPhrase.new(params[:search_phrase])
    @search_phrase.created_by = current_admin.email
    respond_to do |format|
      if @search_phrase.save
        format.html { redirect_to(admin_search_phrases_url, :notice => 'SearchPhrase was successfully created.') }
        format.xml  { render :xml => @search_phrase, :status => :created, :location => @search_phrase }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @search_phrase.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /search_phrases/1
  # PUT /search_phrases/1.xml
  def update
    @search_phrase = SearchPhrase.find(params[:id])
    @search_phrase.attributes = params[:search_phrase]
    @search_phrase.updated_by = current_admin.email
    respond_to do |format|
      if @search_phrase.save
        format.html { redirect_to(admin_search_phrases_url, :notice => 'SearchPhrase was successfully updated.') }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @search_phrase.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /search_phrases/1
  # DELETE /search_phrases/1.xml
  def destroy
    @search_phrase = SearchPhrase.find(params[:id])
    @search_phrase.destroy

    respond_to do |format|
      format.html { redirect_to(admin_search_phrases_url) }
      format.xml  { head :ok }
    end
  end
end
