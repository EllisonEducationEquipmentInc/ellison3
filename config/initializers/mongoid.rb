# encoding: utf-8
module Mongoid #:nodoc:
  module Document
    
    # copies the passed document's values of common fields to self. to exclude certain fields, pass them after the first argument (optional)
    # === Example:
    #   @token = Token.new
    #   @token.copy_common_attributes Payment.last, :status
    def copy_common_attributes(*args)
      document = args.shift
      raise "first argument has to be an instance of a Mongoid::Document descendant" unless document.is_a? Mongoid::Document
      common_attributes = self.fields.map {|e| e[0]} & document.fields.map {|e| e[0]}
      common_attributes.reject {|k,v| args.include? k.to_sym}.each { |e|  self.send("#{e}=", document.send(e))}
    end
  end
end