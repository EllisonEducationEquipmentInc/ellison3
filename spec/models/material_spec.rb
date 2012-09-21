require 'spec_helper'

describe Material do
  subject { Material.new }
  its(:download_only) { should be_false }
end
