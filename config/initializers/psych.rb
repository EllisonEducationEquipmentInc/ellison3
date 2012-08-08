# APPLIES RUBY PATCH REVISION 31075

module Psych
  module Visitors

    class Visitor

    end
 
    ###
    # YAMLTree builds a YAML ast given a ruby object.  For example:
    #
    #   builder = Psych::Visitors::YAMLTree.new
    #   builder << { :foo => 'bar' }
    #   builder.tree # => #<Psych::Nodes::Stream .. }
    #
    class YAMLTree < Psych::Visitors::Visitor

      def accept target
        # return any aliases we find
        if node = @st[target.object_id]
          node.anchor = target.object_id.to_s
          return @emitter.alias target.object_id.to_s
        end

        if target.respond_to?(:to_yaml)
          loc = target.public_method(:to_yaml).source_location.first
          if loc !~ /(syck\/rubytypes.rb|psych\/core_ext.rb)/
            unless target.respond_to?(:encode_with)
              if $VERBOSE
                warn "implementing to_yaml is deprecated, please implement \"encode_with\""
              end

              target.to_yaml(:nodump => true)
            end
          end
        end

        if target.respond_to?(:encode_with)
          dump_coder target
        else
          send(@dispatch_cache[target.class], target)
        end
      end

      private

      # FIXME: remove this method once "to_yaml_properties" is removed
      def find_ivars target
        loc = target.public_method(:to_yaml_properties).source_location.first
        unless loc.start_with?(Psych::DEPRECATED) || loc.end_with?('rubytypes.rb')
          if $VERBOSE
            warn "#{loc}: to_yaml_properties is deprecated, please implement \"encode_with(coder)\""
          end
          return target.to_yaml_properties
        end

        target.instance_variables
      end

    end
  end
end
