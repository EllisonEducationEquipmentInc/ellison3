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
  
  # use #in_batches to prevent CURSOR_NOT_FOUND exceptions: Cursor naturally time out after ten minutes, which means that if you happen to be iterating over a cursor for more than ten minutes, you risk a CURSOR_NOT_FOUND exception.
  class Criteria 
    def in_batches(limit=1000)
      skip = 0
      objects = Mongoid::Criteria.translate(self).limit(limit).skip(skip*limit)
      while objects.any?
        yield objects
        break if objects.size < limit
        skip+=1
        objects = Mongoid::Criteria.translate(self).limit(limit).skip(skip*limit)
      end
    end
  end
  
  module Associations #:nodoc:
    module EmbeddedCallbacks

      # bubble callbacks to embedded associations
      def run_callbacks(kind, *args, &block)
        # now bubble callbacks down
        self.associations.each_pair do |name, meta|
          if meta.relation == Mongoid::Relations::Embedded::Many #Mongoid::Associations::EmbedsMany
            self.send(name).each { |doc| doc.send(:run_callbacks, kind, *args, &block) }
          elsif meta.relation == Mongoid::Relations::Embedded::One #Mongoid::Associations::EmbedsOne
            self.send(name).send(:run_callbacks, kind, *args, &block) unless self.send(name).blank?
          end
        end
        super(kind, *args, &block) # defer to parent
      end

    end
  end
end
