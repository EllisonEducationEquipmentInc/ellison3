require 'spec_helper'

describe Compatibility do
  subject { Compatibility.new }
  its(:products) { should be_empty }
end
