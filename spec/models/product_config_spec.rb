require 'spec_helper'

describe ProductConfig do
  subject { ProductConfig.new }
  its(:name) { should be_nil }
end
