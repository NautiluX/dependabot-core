# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/git_commit_checker"
require "dependabot/swift/file_updater/manifest_updater"

module Dependabot
  module Swift
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      require_relative "update_checker/version_resolver"

      def latest_version
        @latest_version ||= fetch_latest_version
      end

      def latest_resolvable_version
        @latest_resolvable_version ||= fetch_latest_resolvable_version
      end

      def latest_resolvable_version_with_no_unlock
        raise NotImplementedError
      end

      def updated_requirements
        map_requirements do |requirement|
          parsed_requirement = NativeRequirement.new(requirement[:metadata][:requirement_string])
          parsed_requirement.bump_to_satisfy(preferred_resolvable_version)
        end
      end

      def requirements_unlocked_or_can_be?
        requirements_update_strategy != :lockfile_only
      end

      def requirements_update_strategy
        # If passed in as an option (in the base class) honour that option
        return @requirements_update_strategy.to_sym if @requirements_update_strategy

        # Otherwise, bump requirements only when necessary
        :bump_versions_if_necessary
      end

      private

      def old_requirements
        dependency.requirements
      end

      def map_requirements
        old_requirements.map do |old_requirement|
          new_requirement = yield(old_requirement)

          old_requirement.merge(
            requirement: new_requirement.to_s,
            metadata: { requirement_string: new_requirement.declaration }
          )
        end
      end

      def fetch_latest_version
        return unless git_commit_checker.pinned_ref_looks_like_version? && latest_version_tag

        latest_version_tag.fetch(:version)
      end

      def fetch_latest_resolvable_version
        version_resolver.latest_resolvable_version
      end

      def version_resolver
        VersionResolver.new(
          dependency: dependency,
          manifest: prepared_manifest,
          repo_contents_path: repo_contents_path,
          credentials: credentials
        )
      end

      def prepared_manifest
        unprepared_manifest = dependency_files.find { |file| file.name == "Package.swift" }

        unlocked_requirements = map_requirements do |_old_requirement|
          NativeRequirement.new("\"#{dependency.version}\"...\"#{latest_version}\"")
        end

        DependencyFile.new(
          name: unprepared_manifest.name,
          content: FileUpdater::ManifestUpdater.new(
            unprepared_manifest.content,
            old_requirements: old_requirements,
            new_requirements: unlocked_requirements
          ).updated_manifest_content
        )
      end

      def latest_version_resolvable_with_full_unlock?
        # Full unlock checks aren't implemented for Swift (yet)
        false
      end

      def updated_dependencies_after_full_unlock
        raise NotImplementedError
      end

      def git_commit_checker
        @git_commit_checker ||= Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials,
          ignored_versions: ignored_versions,
          raise_on_ignored: raise_on_ignored,
          consider_version_branches_pinned: true
        )
      end

      def latest_version_tag
        git_commit_checker.local_tag_for_latest_version
      end
    end
  end
end

Dependabot::UpdateCheckers.
  register("swift", Dependabot::Swift::UpdateChecker)
