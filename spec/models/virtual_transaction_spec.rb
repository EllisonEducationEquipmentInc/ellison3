require 'spec_helper'

describe VirtualTransaction do
  subject { VirtualTransaction.new }
  its(:user) { should be_nil }
end
