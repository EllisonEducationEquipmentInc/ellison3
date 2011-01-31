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
  
  # This module handles the behaviour for setting up document created at and
  # updated at timestamps.
  module Timestamps
    extend ActiveSupport::Concern

    included do
      field :created_at, :type => Time
      field :updated_at, :type => Time

      attr_accessor :_skip_timestamps
      
      set_callback :create, :before, :set_created_at
      set_callback :save, :before, :set_updated_at, :unless => Proc.new {|p| p._skip_timestamps || !p.changed?}

      class_attribute :record_timestamps
      self.record_timestamps = true
    end

    # Update the created_at field on the Document to the current time. This is
    # only called on create.
    #
    # @example Set the created at time.
    #   person.set_created_at
    def set_created_at
      return if self.class.record_timestamps == false
      self.created_at = Time.now.utc if !created_at
    end

    # Update the updated_at field on the Document to the current time.
    # This is only called on create and on save.
    #
    # @example Set the updated at time.
    #   person.set_updated_at
    def set_updated_at
      return if self.class.record_timestamps == false
      self.updated_at = Time.now.utc
    end
  end
  
  module Associations #:nodoc:
    module EmbeddedCallbacks

      # bubble callbacks to embedded associations
      def run_callbacks(kind, *args, &block)
        # now bubble callbacks down
        self.relations.each_pair do |name, meta|
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


