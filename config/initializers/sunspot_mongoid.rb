module Sunspot #:nodoc:
  module Rails #:nodoc:
    # 
    # This module adds an after_filter to ActionController::Base that commits
    # the Sunspot session if any documents have been added, changed, or removed
    # in the course of the request.
    #
    module RequestLifecycle
      class <<self
        def included(base) #:nodoc:
          loaded_controllers =
            [base].concat(base.subclasses.map { |subclass| subclass.to_s.constantize })
          # Depending on how Sunspot::Rails is loaded, there may already be
          # controllers loaded into memory that subclass this controller. In
          # this case, since after_filter uses the inheritable_attribute
          # structure, the already-loaded subclasses don't get the filters. So,
          # the below ensures that all loaded controllers have the filter.
          loaded_controllers.each do |controller|
            controller.after_filter do
              if Sunspot::Rails.configuration.auto_commit_after_request?
                Sunspot.commit_if_dirty
              elsif Sunspot::Rails.configuration.auto_commit_after_delete_request?
                Sunspot.commit_if_delete_dirty
              end
            end
          end
        end
      end
    end
    
    module Searchable
      module InstanceMethods
      
      private
        def maybe_auto_index
          if @marked_for_auto_indexing
            reload
            solr_index
            remove_instance_variable(:@marked_for_auto_indexing)
          end
        end
      end
    end
  end
end

#Sunspot.session = Sunspot::Rails.build_session
ActionController::Base.module_eval { include(Sunspot::Rails::RequestLifecycle) }
require 'memory'
Sunspot::Adapters::InstanceAdapter.register(Memory::InstanceAdapter, SearchFacet)
Sunspot::Adapters::DataAccessor.register(Memory::DataAccessor, SearchFacet )