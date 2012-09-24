require 'spec_helper'

describe Account do
  subject { Account.new }
  its(:active) { should be_true }
end
