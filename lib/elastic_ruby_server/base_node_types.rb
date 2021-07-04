# frozen_string_literal: true
module ElasticRubyServer
  module BaseNodeTypes
    class Base
      def initialize(node)
        @node = node
      end

      attr_reader :node

      def scope_names
        []
      end

      def category
        self.class::Category
      end

      def node_name
        node.children[0]
      end

      def node_type
        node.type
      end

      def start_line
        node.loc.line
      end

      def start_column
        node.loc.column
      end

      def end_column
        node.loc.last_column
      end
    end

    class NodeMissing < Base; end

    class Assignment < Base
      Category = :assignment

      def scope_names
        [node_name]
      end

      private

      def find_end_column
        offset = node.to_s.match(/#{node_type} :(.*)(\n|\))/)[1].length
        start_column + offset
      end
    end

    class Usage < Base
      Category = :usage

      def scope_names
        []
      end
    end

    class ConstantWithBlockAssignment < Assignment
      def scope_names
        node_names(node)
      end

      def start_column
        if node.type == :casgn
          node.loc.column
        else
          node.children[0].loc.column
        end
      end

      def end_column
        if node.type == :casgn
          node.loc.last_column
        else
          node.children[0].loc.last_column
        end
      end

      def node_name(ast = node)
        if ast.type == :casgn
          ast.children[1]
        else
          ast.children[0].children[1]
        end
      end

      private

      def node_names(ast, names: [])
        name = node_name(ast)
        children = ast.type != :casgn && ast.children[0].children[0] # namespace

        if children
          namespace(children).flatten.compact << name
        else
          [name]
        end
      end

      def namespace(node, names: [])
        node.children.map do |child|
          if child.respond_to?(:children)
            name = child.children[1]
            names << name

            namespace(child, names: names)
          else
            child
          end
        end
      end
    end
  end
end
