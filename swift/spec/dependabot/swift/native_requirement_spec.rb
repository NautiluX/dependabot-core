# frozen_string_literal: true

require "spec_helper"
require "dependabot/swift/native_requirement"

RSpec.describe Dependabot::Swift::NativeRequirement do
  describe ".new" do
    subject { described_class.new(requirement_string).to_s }

    context "with from" do
      let(:requirement_string) { 'from: "1.0.0"' }
      it { is_expected.to eq(">= 1.0.0, < 2.0.0") }
    end

    context "with exact" do
      let(:requirement_string) { 'exact: "1.0.0"' }
      it { is_expected.to eq("= 1.0.0") }
    end

    context "with .upToNextMajor" do
      let(:requirement_string) { '.upToNextMajor(from: "1.0.0")' }
      it { is_expected.to eq(">= 1.0.0, < 2.0.0") }
    end

    context "with .upToNextMinor" do
      let(:requirement_string) { '.upToNextMinor(from: "1.0.0")' }
      it { is_expected.to eq(">= 1.0.0, < 1.1.0") }
    end

    context "with .exact" do
      let(:requirement_string) { '.exact("1.0.0")' }
      it { is_expected.to eq("= 1.0.0") }
    end

    context "with a range requirement" do
      let(:requirement_string) { '"1.0.0"..<"2.0.0"' }
      it { is_expected.to eq(">= 1.0.0, < 2.0.0") }
    end

    context "with a closed range requirement" do
      let(:requirement_string) { '"1.0.0"..."2.0.0"' }
      it { is_expected.to eq(">= 1.0.0, <= 2.0.0") }
    end
  end
end
