require 'spec_helper'

describe FedexZone do
  subject { FedexZone.new }
  its(:created_by) { should be_nil }
end
