require 'spec_helper'

describe RetailerApplication do
  subject { RetailerApplication.new }
  its(:no_website) { should be_false }
end
