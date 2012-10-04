class SearchPhrase
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :phrase
  field :active, :type => Boolean, :default => true
  field :destination
  field :systems_enabled, :type => Array

  field :created_by
  field :updated_by

  scope :active, :where => { :active => true }

  cache

  class << self
    def available(sys = current_system)
      active.where(:systems_enabled.in => [sys])
    end
  end

  index :phrase
  index :active
  index :systems_enabled

  validates_presence_of :phrase, :destination, :systems_enabled

  def destroy
    update_attribute :active, false
  end
end
