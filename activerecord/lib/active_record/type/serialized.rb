# frozen_string_literal: true

module ActiveRecord
  module Type
    class Serialized < DelegateClass(ActiveModel::Type::Value) # :nodoc:
      undef to_yaml if method_defined?(:to_yaml)

      include ActiveModel::Type::Helpers::Mutable

      attr_reader :subtype, :coder

      def initialize(subtype, coder, default: nil)
        @subtype = subtype
        @coder = coder
        @default = default
        super(subtype)
      end

      def deserialize(value)
        if default_value?(value)
          value
        else
          coder.load(super)
        end
      end

      def serialize(value)
        return if value.nil?
        unless default_value?(value) && @default.nil?
          super coder.dump(value)
        end
      end

      def inspect
        Kernel.instance_method(:inspect).bind_call(self)
      end

      def changed_in_place?(raw_old_value, value)
        return false if value.nil?
        raw_new_value = encoded(value)
        raw_old_value.nil? != raw_new_value.nil? ||
          subtype.changed_in_place?(raw_old_value, raw_new_value)
      end

      def accessor
        ActiveRecord::Store::IndifferentHashAccessor
      end

      def assert_valid_value(value)
        if coder.respond_to?(:assert_valid_value)
          coder.assert_valid_value(value, action: "serialize")
        end
      end

      def force_equality?(value)
        coder.respond_to?(:object_class) && value.is_a?(coder.object_class)
      end

      private
        def default_value?(value)
          value == coder.load(nil)
        end

        def encoded(value)
          return if default_value?(value)
          payload = coder.dump(value)
          if payload && binary? && payload.encoding != Encoding::BINARY
            payload = payload.dup if payload.frozen?
            payload.force_encoding(Encoding::BINARY)
          end
          payload
        end
    end
  end
end
