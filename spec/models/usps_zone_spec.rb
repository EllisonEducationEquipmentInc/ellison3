require 'spec_helper'

describe UspsZone do
  subject { UspsZone.new }
  its(:zip_prefix) { should be_nil }
end
