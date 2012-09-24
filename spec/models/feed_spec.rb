require 'spec_helper'

describe Feed do
  subject { Feed.new }
  its(:feeds) { should be_nil }
end
