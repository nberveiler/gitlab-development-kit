# frozen_string_literal: true

module RuboCop
  module Cop
    # Cop that discourages use of Time.new
    #
    class AvoidTimeNew < RuboCop::Cop::Cop
      MSG = 'Use `Time.now` instead of `Time.new` to ensure `ActiveSupport::Testing::TimeHelpers.freeze_time` works effectively.'

      def_node_matcher :time_new?, '(send (const _ :Time) :new)'

      def on_send(node)
        add_offense(node, location: :expression) if time_new?(node)
      end
    end
  end
end
