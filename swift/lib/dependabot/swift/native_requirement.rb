# frozen_string_literal: true

require "dependabot/utils"
require "dependabot/swift/requirement"
require "dependabot/swift/version"

module Dependabot
  module Swift
    class NativeRequirement
      attr_reader :declaration

      def initialize(declaration)
        @declaration = declaration

        min, max, constraint = parse_declaration(declaration)

        @min = min
        @max = max
        @requirement = Requirement.new(constraint)
      end

      def to_s
        requirement.to_s
      end

      def bump_to_satisfy(str)
        version = Version.new(str)

        return self if requirement.satisfied_by?(version)

        new_declaration = if up_to_next_major?
          new_version = min.end_with?(".0.0") ? "#{version.segments.first}.0.0" : str
          declaration.sub(min, new_version)
        elsif up_to_next_minor?
          new_version = min.end_with?(".0") ? "#{version.segments.first}.#{version.segments.second}.0" : str
          declaration.sub(min, new_version)
        elsif inclusive_range?
          declaration.sub(max, str)
        elsif exclusive_range?
          declaration.sub(max, bump_major(str))
        elsif exact_version?
          declaration.sub(min, str)
        end

        self.class.new(new_declaration)
      end

      private

      def parse_declaration(declaration)
        if up_to_next_major?
          min = unquote(delete_around(declaration.delete_prefix("from:"), ".upToNextMajor(from:", ")").strip)
          max = bump_major(min)
          constraint = [">= #{min}", "< #{max}"]
        elsif up_to_next_minor?
          min = unquote(delete_around(declaration, ".upToNextMinor(from:", ")").strip)
          max = bump_minor(min)
          constraint = [">= #{min}", "< #{max}"]
        elsif inclusive_range?
          min, max = declaration.split("...").map { |str| unquote(str) }
          constraint = [">= #{min}", "<= #{max}"]
        elsif exclusive_range?
          min, max = declaration.split("..<").map { |str| unquote(str) }
          constraint = [">= #{min}", "< #{max}"]
        elsif exact_version?
          min = unquote(delete_around(declaration.delete_prefix("exact:"), ".exact(", ")").strip)
          max = min
          constraint = ["= #{min}"]
        else
          raise "Unsupported constraint: #{declaration}"
        end

        [min, max, constraint]
      end

      def bump_major(str)
        transform_version(str) do |s, i|
          i.zero? ? s.to_i + 1 : 0
        end
      end

      def bump_minor(str)
        transform_version(str) do |s, i|
          if i.zero?
            s
          else
            (i == 1 ? s.to_i + 1 : 0)
          end
        end
      end

      def transform_version(str, &block)
        str.split(".").map.with_index(&block).join(".")
      end

      def up_to_next_major?
        declaration.start_with?("from:", ".upToNextMajor(from:")
      end

      def up_to_next_minor?
        declaration.start_with?(".upToNextMinor(from:")
      end

      def exact_version?
        declaration.start_with?(".exact(", "exact:")
      end

      def inclusive_range?
        declaration.include?("...")
      end

      def exclusive_range?
        declaration.include?("..<")
      end

      attr_reader :min, :max, :requirement

      def delete_around(declaration, prefix, suffix)
        declaration.delete_prefix(prefix).delete_suffix(suffix)
      end

      def unquote(declaration)
        declaration[1..-2]
      end
    end
  end
end

Dependabot::Utils.
  register_requirement_class("swift", Dependabot::Swift::Requirement)
