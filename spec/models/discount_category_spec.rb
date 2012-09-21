require 'spec_helper'

describe DiscountCategory do
  subject { DiscountCategory.new }
	its(:active) { should be_true }
end
