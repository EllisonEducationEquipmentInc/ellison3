class Comment
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :admin_reply, :type => Boolean, :default => false
	field :message
	field :email
	
	validates_presence_of :message
	
	embedded_in :feedback, :inverse_of => :comments

  after_initialize Proc.new {|obj| obj.created_at = Time.zone.now}
end
