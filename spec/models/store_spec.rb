require 'spec_helper'

describe Store do
  subject { Store.new }
  its(:webstore) { should be_false }
end
