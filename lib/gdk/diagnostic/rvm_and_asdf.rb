# frozen_string_literal: true

module GDK
  module Diagnostic
    class RvmAndAsdf < Base
      TITLE = 'RVM and asdf'

      def diagnose
        nil
      end

      def success?
        !rvm_and_asdf_enabled?
      end

      def detail
        return rvm_and_asdf_enabled_message if rvm_and_asdf_enabled?
      end

      private

      def rvm_and_asdf_enabled?
        !ENV['rvm_path'].to_s.empty? && !ENV['ASDF_DIR'].to_s.empty?
      end

      def rvm_and_asdf_enabled_message
        <<~MESSAGE
          RVM and asdf appear to both be enabled. This has been known to cause
          issues with asdf compiling tools.
        MESSAGE
      end
    end
  end
end
