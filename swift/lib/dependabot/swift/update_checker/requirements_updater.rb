# frozen_string_literal: true

require "dependabot/update_checkers/base"
require "dependabot/swift/native_requirement"
require "dependabot/swift/version"

module Dependabot
  module Swift
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      class RequirementsUpdater
        ALLOWED_UPDATE_STRATEGIES =
          %i(lockfile_only bump_versions bump_versions_if_necessary).freeze

        def initialize(requirements:, update_strategy:, target_version:)
          @requirements = requirements
          @update_strategy = update_strategy

          check_update_strategy

          return unless target_version && Version.correct?(target_version)

          @target_version = Version.new(target_version)
        end

        def updated_requirements
          return requirements if update_strategy == :lockfile_only

          NativeRequirement.map_requirements(requirements) do |requirement|
            if update_strategy == :bump_versions_if_necessary
              requirement.update_if_needed(target_version)
            else
              requirement.update(target_version)
            end
          end
        end

        private

        attr_reader :requirements, :update_strategy, :target_version

        def check_update_strategy
          return if ALLOWED_UPDATE_STRATEGIES.include?(update_strategy)

          raise "Unknown update strategy: #{update_strategy}"
        end
      end
    end
  end
end
