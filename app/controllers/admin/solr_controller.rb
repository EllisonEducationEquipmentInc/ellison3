class Admin::SolrController < ApplicationController
  layout 'admin'

  before_filter :set_admin_title
 	before_filter :admin_read_permissions!
  before_filter :admin_write_permissions!

 	ssl_exceptions
 	
 	verify :xhr => true, :only => [:commit]
	
 	def index
 	  
 	end
 	
 	def commit
 	  Sunspot.commit
 	  render :js => "alert('solr has been committed')"
 	end
end
