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
      objects = self.limit(limit).skip(skip*limit)
      while objects.size > 0
        yield objects
        break if objects.size < limit
        skip+=1
        objects = self.limit(limit).skip(skip*limit)
      end
    end
  end
  
  # This module handles the behaviour for setting up document created at and
  # updated at timestamps.
  module Timestamps
    module Updated
      extend ActiveSupport::Concern

      included do
        field :updated_at, :type => Time
        attr_accessor :_skip_timestamps
        
        set_callback :save, :before, :set_updated_at, :if => Proc.new { |doc|
          !doc._skip_timestamps && (doc.new_record? || doc.changed?)
        }

        unless methods.include? 'record_timestamps'
          class_attribute :record_timestamps
          self.record_timestamps = true
        end
      end

      # Update the updated_at field on the Document to the current time.
      # This is only called on create and on save.
      #
      # @example Set the updated at time.
      #   person.set_updated_at
      def set_updated_at
        self.updated_at = Time.now.utc
      end
    end
  end
  
  # do NOT validate the other side of references_and_referenced_in_many association
  module Relations #:nodoc:
    
    class Many < Proxy
      def <<(*args)
        options = default_options(args)
        args.flatten.each do |doc|
          return doc unless doc
          append(doc, options)
          doc.save(:validate => false) if base.persisted? && !options[:binding]
        end
      end
    end
    
    module Referenced #:nodoc:
      class Many < Relations::Many
        def bind(options = {})
          binding.bind(options)
          target.map {|e| e.save(:validate => false)} if base.persisted? && !options[:binding]
        end
      end
      
      class ManyToMany < Referenced::Many                
        def <<(*args)
          options = default_options(args)
          args.flatten.each do |doc|
            return doc unless doc
            append(doc, options)
            if base.persisted? && !options[:binding]
              base.add_to_set(metadata.foreign_key, doc.id)
              doc.save(:validate => false) if base.persisted? && !options[:binding]
            end
          end
        end
      end
    end
  end
  
  module Associations #:nodoc:
    module EmbeddedCallbacks

      # bubble callbacks to embedded associations
      def run_callbacks(kind, *args, &block)
        # now bubble callbacks down
        self.relations.each_pair do |name, meta|
          if meta.relation == Mongoid::Relations::Embedded::Many #Mongoid::Associations::EmbedsMany
            Rails.logger.info "!!! running callback #{kind} #{args} for #{name} called by #{self.class}"
            self.send(name).each { |doc| doc.send(:run_callbacks, kind, *args, &block) }
          elsif meta.relation == Mongoid::Relations::Embedded::One #Mongoid::Associations::EmbedsOne
            Rails.logger.info "!!! running callback #{kind} #{args} for #{name} called by #{self.class}"
            self.send(name).send(:run_callbacks, kind, *args, &block) unless self.send(name).blank?
          end
        end
        super(kind, *args, &block) # defer to parent
      end

    end
  end
end


