require 'spec_helper'

describe ShippingRate do
  subject { ShippingRate.new }
  its(:percentage) { should be_false }
end
