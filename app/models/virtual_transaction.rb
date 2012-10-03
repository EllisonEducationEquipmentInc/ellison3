class VirtualTransaction
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user
  field :transaction_type
  field :result
  field :raw_result
  field :transaction_id
  field :details, :type => Hash
end
