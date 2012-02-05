class Blogger
  include Mongoid::Document
  include Mongoid::Timestamps
  include EllisonSystem

  field :name
  field :blog_url
  field :photo_url
  field :systems_enabled, :type => Array
  field :created_by
  field :updated_by

  validates_presence_of :name, :blog_url, :systems_enabled

  ELLISON_SYSTEMS.each do |sys|
    scope sys.to_sym, :where => { :systems_enabled.in => [sys] }
  end
end
