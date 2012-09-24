require 'spec_helper'

describe MaterialOrder do
  subject { MaterialOrder.new }
  its(:order_number) { should be_nil }
end
