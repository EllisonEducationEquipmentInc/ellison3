class StaticPage
  include Mongoid::Document
  include EllisonSystem
  include Mongoid::Timestamps

  field :name
  field :active, :type => Boolean, :default => true
  field :system_enabled
  field :permalink
  field :short_desc
  field :content
  field :haml_content

  field :created_by
  field :updated_by

  index :permalink
  index :name
  index :system_enabled
  index :active

  validates :name, :system_enabled, :permalink, :presence => true
  validates_inclusion_of :system_enabled, :in => ELLISON_SYSTEMS
  validates_format_of :permalink, :with => /^[_a-z0-9-]+$/, :message => "Use only alphanumeric characters, dash and underscore (all lowercase, no spaces or special characters). Examle: st-patrick-day-sale"
  validate :permalink_uniqueness

  scope :active, :where => { :active => true }

  def destroy
    update_attribute :active, false
  end

  private

  def permalink_uniqueness
    errors.add(:permalink, "Permalink %s already exists in #{self.system_enabled}") if self.class.where(:_id.ne => self.id, :permalink => self.permalink, :system_enabled => self.system_enabled).count > 0
  end

end
