require 'spec_helper'

describe FedexRate do
  subject { FedexRate.new }
  its(:weight_max) { should be_nil }
end
