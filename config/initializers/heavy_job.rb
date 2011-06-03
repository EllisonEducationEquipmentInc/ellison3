# use this class to perform heavy operations in the background by DJ (ddelayed_job)
# example: @tag.products.nullify caused passenger to grow memory over the limit.
# with "HeavyJob":
#
#   Delayed::Job.enqueue HeavyJob.new @tag, :products, :nullify, :save, :validate => false
HeavyJob = Struct.new(:obj, :collection, :method_to_perform, :callback, :callback_args) do
  def perform
    obj.send(collection).send(method_to_perform)
    obj.send(callback, callback_args) if callback
  end
end