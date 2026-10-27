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
    Dir.mktmpdir("fastlane-cwd-") do |working_directory|
      Dir.chdir(working_directory) do
        assert_equal "1.29.0", app_version_from_pubspec
      end
    end
  end
end
