# frozen_string_literal: true

require "dependabot/config/ignore_condition"

require "wildcard_matcher"
require "yaml"

module Dependabot
  class DependencyGroup
    ANY_DEPENDENCY_NAME = "*"
    SECURITY_UPDATES_ONLY = false

    class NullIgnoreCondition
      def ignored_versions(_dependency, _security_updates_only)
        []
      end
    end

    attr_reader :name, :rules, :dependencies

    def initialize(name:, rules:)
      @name = name
      @rules = rules
      @dependencies = []
      @ignore_condition = generate_ignore_condition!
    end

    def contains?(dependency)
      return true if @dependencies.include?(dependency)

      matches_pattern?(dependency.name) && matches_dependency_type?(dependency)
    end

    # This method generates ignored versions for the given Dependency based on
    # the any update-types we have defined.
    def ignored_versions_for(dependency)
      @ignore_condition.ignored_versions(dependency, SECURITY_UPDATES_ONLY)
    end

    def to_h
      { "name" => name }
    end

    # Provides a debug utility to view the group as it appears in the config file.
    def to_config_yaml
      {
        "groups" => { name => rules }
      }.to_yaml.delete_prefix("---\n")
    end

    private

    # TODO: Decouple pattern and exclude-pattern
    #
    # I think we'll probably want to permit someone to group by dependency type but still use exclusions?
    #
    # We probably need to think a lot more about validation to ensure we have _at least one_ positive-match rule
    # out of pattern, dependency-type, etc, as well as `exclude-pattern` or we'll need to support it as an implicit
    # "everything except exclude-patterns" if it can be configured on its own.
    #
    def matches_pattern?(dependency_name)
      return true unless pattern_rules? # If no patterns are defined, we pass this check by default

      positive_match = rules["patterns"].any? { |rule| WildcardMatcher.match?(rule, dependency_name) }
      negative_match = rules["exclude-patterns"]&.any? { |rule| WildcardMatcher.match?(rule, dependency_name) }

      positive_match && !negative_match
    end

    def matches_dependency_type?(dependency)
      return true unless dependency_type_rules? # If no dependency-type is set, match by default

      rules["dependency-type"] == if dependency.production?
                                    "production"
                                  else
                                    "development"
                                  end
    end

    def pattern_rules?
      rules.key?("patterns") && rules["patterns"]&.any?
    end

    def dependency_type_rules?
      rules.key?("dependency-type")
    end

    def generate_ignore_condition!
      return NullIgnoreCondition.new unless rules["update-types"]&.any?

      Dependabot::Config::IgnoreCondition.new(
        dependency_name: ANY_DEPENDENCY_NAME,
        update_types: Dependabot::Config::IgnoreCondition::VERSION_UPDATE_TYPES - rules["update-types"]
      )
    end
  end
end
