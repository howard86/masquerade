#!/usr/bin/env ruby

require "minitest/autorun"
require "tmpdir"

# Load Fastfile without Fastlane so this regression test never invokes a lane.
def default_platform(_platform); end
def platform(_platform)
  yield
end
def desc(_description); end
def lane(_name); end

load File.expand_path("Fastfile", __dir__)

class FastfileVersionPathTest < Minitest::Test
  def test_pubspec_version_is_resolved_from_fastfile_location_not_current_directory
    repository_root = File.expand_path("../..", __dir__)
    expected_version = File.read(File.join(repository_root, "pubspec.yaml"))[
      /^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/,
      1
    ]
    refute_nil expected_version

    Dir.mktmpdir("fastlane-cwd-") do |working_directory|
      Dir.chdir(working_directory) do
        assert_equal expected_version, app_version_from_pubspec
      end
    end
  end
end
