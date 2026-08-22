# frozen_string_literal: true

require "json"

class WebUiPin
  REQUIRED_KEYS = %w[kind repository revision commit].freeze
  GITHUB_REPOSITORY = %r{\A(?:https://github\.com/|ssh://git@github\.com/|git@github\.com:)([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?\z}
  COMMIT = /\A[0-9a-f]{40}\z/

  def self.verify!(path, expected_repository:, expected_commit:)
    source = parse_source(File.read(path, encoding: "UTF-8"))
    missing = REQUIRED_KEYS - source.keys
    raise ArgumentError, "Web UI source is missing #{missing.join(", ")}" unless missing.empty?
    raise ArgumentError, "Web UI source kind must be git" unless source.fetch("kind") == "git"

    repository = github_repository(source.fetch("repository"))
    unless repository == expected_repository
      raise ArgumentError, "Web UI repository #{repository} differs from #{expected_repository}"
    end

    commit = source.fetch("commit")
    raise ArgumentError, "Web UI commit must be a full lowercase SHA" unless COMMIT.match?(commit)
    return true if commit == expected_commit

    raise ArgumentError, "Web UI commit #{commit} differs from #{expected_commit}"
  end

  def self.parse_source(text)
    current_table = nil
    source = {}
    text.each_line.with_index(1) do |raw_line, line_number|
      line = raw_line.strip
      next if line.empty? || line.start_with?("#")

      if (table = line.match(/\A\[([A-Za-z0-9_.-]+)\]\z/))
        current_table = table[1]
        next
      end
      next unless current_table == "source"

      assignment = line.match(/\A([A-Za-z0-9-]+)\s*=\s*("(?:[^"\\]|\\.)*")\s*(?:#.*)?\z/)
      raise ArgumentError, "invalid Web UI source value on line #{line_number}" unless assignment

      key = assignment[1]
      raise ArgumentError, "duplicate Web UI source key #{key}" if source.key?(key)

      source[key] = JSON.parse(assignment[2])
    end
    raise ArgumentError, "Web UI configuration is missing [source]" if source.empty?

    source
  end

  def self.github_repository(value)
    match = GITHUB_REPOSITORY.match(value)
    raise ArgumentError, "Web UI repository must be a GitHub repository URL" unless match

    match[1]
  end

  private_class_method :parse_source, :github_repository
end
