# frozen_string_literal: true

require "minitest/autorun"
require "tempfile"
require_relative "../lib/web_ui_pin"

class WebUiPinTest < Minitest::Test
  COMMIT = "b" * 40

  def verify(source, repository: "synctv-org/synctv-app", commit: COMMIT)
    file = Tempfile.new(["web-ui", ".toml"])
    file.write("schema-version = 1\n\n[source]\n#{source}")
    file.close
    WebUiPin.verify!(file.path, expected_repository: repository, expected_commit: commit)
  ensure
    file&.unlink
  end

  def test_accepts_matching_https_pin
    assert verify(<<~TOML)
      kind = "git"
      repository = "https://github.com/synctv-org/synctv-app.git"
      revision = "#{COMMIT}"
      commit = "#{COMMIT}"
    TOML
  end

  def test_accepts_matching_ssh_pin
    assert verify(<<~TOML)
      kind = "git"
      repository = "git@github.com:synctv-org/synctv-app.git"
      revision = "#{COMMIT}"
      commit = "#{COMMIT}"
    TOML
  end

  def test_rejects_a_floating_production_revision
    error = assert_raises(ArgumentError) do
      verify(<<~TOML)
        kind = "git"
        repository = "https://github.com/synctv-org/synctv-app.git"
        revision = "refs/tags/v1.2.3"
        commit = "#{COMMIT}"
      TOML
    end

    assert_includes error.message, "revision must equal its pinned commit"
  end

  def test_rejects_non_git_source
    error = assert_raises(ArgumentError) do
      verify(<<~TOML)
        kind = "dist"
        repository = "https://github.com/synctv-org/synctv-app.git"
        revision = "#{COMMIT}"
        commit = "#{COMMIT}"
      TOML
    end

    assert_includes error.message, "kind must be git"
  end

  def test_rejects_repository_mismatch
    error = assert_raises(ArgumentError) do
      verify(<<~TOML)
        kind = "git"
        repository = "https://github.com/other/app.git"
        revision = "#{COMMIT}"
        commit = "#{COMMIT}"
      TOML
    end

    assert_includes error.message, "differs from synctv-org/synctv-app"
  end

  def test_rejects_commit_mismatch
    mismatched_commit = "a" * 40
    error = assert_raises(ArgumentError) do
      verify(<<~TOML)
        kind = "git"
        repository = "https://github.com/synctv-org/synctv-app.git"
        revision = "#{mismatched_commit}"
        commit = "#{mismatched_commit}"
      TOML
    end

    assert_includes error.message, "differs from #{COMMIT}"
  end

  def test_rejects_duplicate_source_keys
    error = assert_raises(ArgumentError) do
      verify(<<~TOML)
        kind = "git"
        kind = "git"
        repository = "https://github.com/synctv-org/synctv-app.git"
        revision = "#{COMMIT}"
        commit = "#{COMMIT}"
      TOML
    end

    assert_includes error.message, "duplicate Web UI source key kind"
  end
end
