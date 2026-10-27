#!/usr/bin/env ruby

require "minitest/autorun"
require "tmpdir"

$fastlane_lanes = {}
$fastlane_actions = []
$fastlane_lane_context = {}
$fastlane_test_ipa_path = nil
$fastlane_validator_failure = false
$fastlane_missing_ipa = false

module SharedValues
  SIGH_NAME = :sigh_name
  IPA_OUTPUT_PATH = :ipa_output_path
end

module UI
  def self.user_error!(message)
    raise RuntimeError, message
  end

  def self.important(_message); end
end

def default_platform(_platform); end

def platform(_platform)
  yield
end

def desc(_description); end

def lane(name, &block)
  $fastlane_lanes[name.to_sym] = block
end

def lane_context
  $fastlane_lane_context
end

def app_store_connect_api_key(**_options)
  :fake_api_key
end

def get_provisioning_profile(**options)
  $fastlane_actions << [:profile, options]
  profile_number = $fastlane_actions.count { |action| action.first == :profile }
  lane_context[SharedValues::SIGH_NAME] = "profile-#{profile_number}"
end

def update_code_signing_settings(**options)
  $fastlane_actions << [:update_signing, options]
end

def build_app(**options)
  $fastlane_actions << [:build_app, options]
  lane_context[SharedValues::IPA_OUTPUT_PATH] =
    $fastlane_missing_ipa ? nil : $fastlane_test_ipa_path
end

def upload_to_testflight(**options)
  $fastlane_actions << [:upload, options]
end

def sh(*args)
  $fastlane_actions << [:shell, args]
  true
end

load File.expand_path("Fastfile", __dir__)
Object.class_eval do
  alias_method :fastlane_signed_ipa_validator_command, :validate_signed_ipa
end

# Stub only the validator invocation for lane-order tests. The Python fixture
# tests exercise validator decisions with mocked macOS tools separately.
def validate_signed_ipa(**options)
  $fastlane_actions << [:validate, options]
  raise RuntimeError, "validator rejected IPA" if $fastlane_validator_failure
end

class FastfileReleaseSafetyTest < Minitest::Test
  def setup
    @saved_environment = {}
    %w[ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_P8 FLUTTER_BUILD_NUMBER FASTLANE_OUTPUT_DIR].each do |name|
      @saved_environment[name] = ENV[name]
    end

    @temporary_directory = Dir.mktmpdir("fastlane-release-safety-")
    ENV["ASC_KEY_ID"] = "test-key-id"
    ENV["ASC_ISSUER_ID"] = "test-issuer-id"
    ENV["ASC_KEY_P8"] = "test-only-placeholder"
    ENV["FLUTTER_BUILD_NUMBER"] = "83"
    ENV["FASTLANE_OUTPUT_DIR"] = @temporary_directory

    $fastlane_actions.clear
    $fastlane_lane_context.clear
    $fastlane_test_ipa_path = File.join(@temporary_directory, "actual-fastlane-output.ipa")
    $fastlane_validator_failure = false
    $fastlane_missing_ipa = false
    @previous_output = File.join(@temporary_directory, "1.29.0-83-prior")
    Dir.mkdir(@previous_output)
    File.write(File.join(@previous_output, "sentinel"), "keep")
  end

  def teardown
    @saved_environment.each do |name, value|
      value.nil? ? ENV.delete(name) : ENV[name] = value
    end
    FileUtils.remove_entry(@temporary_directory) if File.exist?(@temporary_directory)
  end

  def beta_lane
    $fastlane_lanes.fetch(:beta).call
  end

  def test_both_profiles_are_read_only_and_actual_fastlane_ipa_is_validated_before_upload
    beta_lane

    profile_calls = $fastlane_actions.select { |action| action.first == :profile }
    assert_equal 2, profile_calls.length
    assert_equal "dev.howardism.Masquerade", profile_calls[0][1][:app_identifier]
    assert_equal "dev.howardism.Masquerade.ShareExtension", profile_calls[1][1][:app_identifier]
    assert profile_calls.all? { |action| action[1][:readonly] }

    build_action = $fastlane_actions.find { |action| action.first == :build_app }
    output_directory = build_action[1][:output_directory]
    assert_match(/\A1\.29\.0-83-/, File.basename(output_directory))
    assert_equal @temporary_directory, File.dirname(output_directory)
    assert File.exist?(File.join(@previous_output, "sentinel"))

    validation_index = $fastlane_actions.index { |action| action.first == :validate }
    upload_index = $fastlane_actions.index { |action| action.first == :upload }
    assert_operator validation_index, :<, upload_index
    validation = $fastlane_actions[validation_index][1]
    assert_equal $fastlane_test_ipa_path, validation[:ipa_path]
    assert_equal "1.29.0", validation[:version]
    assert_equal "83", validation[:build_number]

    upload = $fastlane_actions[upload_index][1]
    assert_equal $fastlane_test_ipa_path, upload[:ipa]
  end

  def test_validator_failure_prevents_testflight_upload
    $fastlane_validator_failure = true

    error = assert_raises(RuntimeError) { beta_lane }
    assert_equal "validator rejected IPA", error.message
    refute $fastlane_actions.any? { |action| action.first == :upload }
  end

  def test_missing_fastlane_ipa_fails_before_validation_or_upload
    $fastlane_missing_ipa = true

    error = assert_raises(RuntimeError) { beta_lane }
    assert_equal "Fastlane did not produce an IPA", error.message
    refute $fastlane_actions.any? { |action| action.first == :validate }
    refute $fastlane_actions.any? { |action| action.first == :upload }
  end

  def test_validator_command_uses_the_expected_ids_and_build_number
    Object.new.send(
      :fastlane_signed_ipa_validator_command,
      ipa_path: $fastlane_test_ipa_path,
      version: "1.29.0",
      build_number: "83",
      built_after: 123.5,
    )

    shell = $fastlane_actions.find { |action| action.first == :shell }[1]
    assert_equal "python3", shell[0]
    assert_equal File.expand_path("validate_signed_ipa.py", __dir__), shell[1]
    assert_includes shell, $fastlane_test_ipa_path
    assert_includes shell, "--expected-version"
    assert_includes shell, "1.29.0"
    assert_includes shell, "--expected-build"
    assert_includes shell, "83"
    assert_includes shell, "--built-after"
    assert_includes shell, "123.5"
  end
end
