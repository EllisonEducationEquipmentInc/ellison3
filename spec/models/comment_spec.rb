require 'spec_helper'

describe Comment do
  subject { Comment.new }
  its(:admin_reply) { should be_false }
end
