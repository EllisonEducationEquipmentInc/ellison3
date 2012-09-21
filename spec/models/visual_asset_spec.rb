require 'spec_helper'

describe VisualAsset do
  subject { VisualAsset.new }
  its(:item_limit) { should eql(12) }
end
