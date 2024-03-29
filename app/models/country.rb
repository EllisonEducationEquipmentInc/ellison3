class Country
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  cache

  field :systems_enabled, :type => Array
  field :iso_name
  field :iso
  field :name
  field :iso3
  field :numcode
  field :vat_exempt, :type => Boolean, :default => false
  field :gbp, :type => Boolean, :default => false
  field :display_order, :type => Integer, :default => 300

  index :name
  index :systems_enabled
  index :display_order

  validates_presence_of :iso_name, :iso, :name, :iso3, :numcode
  validates_uniqueness_of :iso_name, :iso, :name, :iso3, :on => :create, :message => "must be unique", :case_sensitive => false

  ELLISON_SYSTEMS.each do |sys|
    scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } # dynaically create a scope for each system. ex.:  Country.szus => scope for sizzix US countries
  end

  class << self
    def find_by_name(name)
      where(:name => name).cache.first
    end

    def name_2_code(name)
      Rails.cache.fetch("country_2_code_#{name}", :expires_in => 1.days) do
        find_by_name(name).try :iso
      end
    end
  end
end
