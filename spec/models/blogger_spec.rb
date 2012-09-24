require 'spec_helper'

describe Blogger do
  subject { Blogger.new }
  its(:name) { should be_nil }
end
