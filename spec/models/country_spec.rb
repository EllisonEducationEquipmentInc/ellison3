require 'spec_helper'

describe Country do
  subject { FactoryGirl.build(:country, systems_enabled: %w[szus szuk eeus eeuk erus]) }
  it{ should be_valid }

  describe "initialization" do
    its(:gbp) { should be_false }
    its(:vat_exempt) { should be_false }
    its(:display_order) { should eql(300) }
  end

  describe "validations" do
    it { should validate_presence_of(:iso_name) }
    it { should validate_presence_of(:numcode) }
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:iso3) }
    it { should validate_presence_of(:iso) }
    
    it { should validate_uniqueness_of(:iso_name) }
    it { should validate_uniqueness_of(:iso3) }
    it { should validate_uniqueness_of(:name) }
    it { should validate_uniqueness_of(:iso) }
  end
end
