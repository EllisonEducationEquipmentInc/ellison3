require 'net/http'
require 'net/https'
require 'builder'
require 'base64'
require 'rexml/document'
require 'rexml/formatters/pretty'
require 'active_support/inflector'
require 'active_support/core_ext/hash'
require 'active_support/inflector'

# ==== Ruby class for Lyris List Manager SOAP API.
#
# LYRIS API INFO:
# http://www.lyris.com/help/lm_api/10.0/
#
# LYRIS_CREDENTIALS constant must be defined using the following format: 
#   LYRIS_CREDENTIALS = "user@domain.com:password"
class Lyris
	
	class LyrisError < StandardError; end #:nodoc:
	
	# Struct class for the @response object.
	Response = Struct.new(:code, :message, :body)
	
	# attributes:
	#  request      #=> returns the request xml sent to lyris
	#  response     #=> returns the response xml returned from lyris
	#  action       #=> returns the requested soap action 
	attr_accessor :request, :response, :ns, :action

  # list of available SOAP actions. The action is automatically converted form :under_score symbol format to CamelizedFormat.
	SOAP_ACTIONS = [:api_version, :current_user_email_address, :delete_members, :get_member_id, :create_single_member, :create_many_members, :sql_select, :sql_insert, :sql_update, :sql_delete, :update_member_password,
		 :check_member_password, :copy_member, :create_list, :delete_list, :email_on_what_lists, :email_password_on_what_lists, :create_list_admin, :create_member_ban, :get_email_from_member_id, :get_list_id, 
			:get_listname_from_member_id, :import_content, :select_members, :select_simple_members, :send_mailing, :mailing_status, :schedule_mailing, :moderate_mailing, :select_content, :select_lists, :select_segments, 
			:send_mailing_direct, :send_member_doc, :tracking_summary, :unsubscribe, :update_member_email, :update_member_kind, :update_member_status, :update_list, :update_list_admin, :update_member_demographics,
			 :create_member_column, :delete_member_column, :create_segment, :update_segment, :delete_segment, :send_message, :create_site, :update_site, :delete_site, :create_topic, :update_topic, :delete_topic, 
			:get_preview_mailing, :create_server_admin, :update_server_admin, :delete_server_admin, :create_site_admin, :update_site_admin, :delete_site_admin, :create_content, :update_content, :delete_content, :select_lists_ex]
	
  # == Examples:
  #
  # create member:
  # l=Lyris.new :create_single_member, :email_address => 'email@ellison.com', :list_name => 'testsizzix', :full_name => 'john smith'
  #
  # get member id:
  # l = Lyris.new :get_member_id, :simple_member_struct_in => {:email_address => 'email@ellison.com', :list_name => 'testsizzix'}
  #
  # update member attributes:
  # l = Lyris.new :update_member_demographics, :simple_member_struct_in => {:email_address => 'email@ellison.com', :list_name => 'testsizzix'}, :demographics_array => [{:name => :eclips, :value => 1}]
  #
  # update member status (ex: 'needs-confirm'):
  # l = Lyris.new :update_member_status, :simple_member_struct_in => {:email_address => 'email@ellison.com', :list_name => 'testsizzix'}, :member_status => 'needs-confirm'
	def initialize(action = :api_version, options = {})
		raise LyrisError, "Invalid Action: #{action}" unless SOAP_ACTIONS.include?(action)
		@options = options
		@ns = @options.delete(:ns) || :ns
		@action = action.to_s.camelize.gsub(/Id$/, 'ID')
		process
	end
	
	# process the action. automatically called when a new Lyris instance is initialized.
	def process
		send_request @action
	end
	
	# returns the result string of the action. 
	def result
		r = REXML::Document.new @response.body
		success? ? r.root.elements['SOAP-ENV:Body'].elements["#{@ns}:#{@action}Response"].elements['return'].text : r.root.elements['SOAP-ENV:Body'].elements["SOAP-ENV:Fault"].elements['faultstring'].text
	end
	
	# Boolean, if action was successful
	def success?
		@response.code == "200"
	end
	
	# Boolean, if action returned an error
	def error?
		!success?
	end
	
private 

  def send_request(action)

		timeout(50) do
			
			http = Net::HTTP.new('lyris.sizzix.com', 82)
			http.use_ssl = false
			path = '/'
			headers = {
			  'Content-Type' => 'text/xml;charset=UTF-8',
			  'Authorization' => 'Basic ' + Base64::encode64(LYRIS_CREDENTIALS)
			}

			@request = build_request(@options.to_xml :skip_instruct => true, :root => "#{@ns}:#{@action}", :camelize => true)

			resp, data = http.post(path, @request, headers)
			
			@response = Response.new resp.code, resp.message, data
		end
  end

	def build_request(body)
	  xml = Builder::XmlMarkup.new :indent => 2
	  xml.instruct!
	  xml.tag!("SOAP-ENV:Envelope", "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance", 'xmlns:xsd' => "http://www.w3.org/2001/XMLSchema", 'xmlns:SOAP-ENC' => "http://schemas.xmlsoap.org/soap/encoding/", "xmlns:SOAP-ENV" => "http://schemas.xmlsoap.org/soap/envelope/", "xmlns:ns1" => "http://tempuri.org/ns1.xsd",  "xmlns:ns" => "http://www.lyris.com/lmapi") do
	    xml.tag!("SOAP-ENV:Body") do
	      xml << body.gsub("Ns:", 'ns:')
	    end
	  end
	  xml.target!
	end

end