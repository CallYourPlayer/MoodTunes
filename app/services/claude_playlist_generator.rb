# Uses the official Anthropic Ruby SDK to turn a free-text situation (plus an
# optional mood and preferred genres) into a list of suggested songs.
#
# Returns an array of { "title" => ..., "artist" => ... } hashes that the
# caller then resolves against YouTube.
class ClaudePlaylistGenerator
  MODEL = :"claude-sonnet-4-6"
  TRACK_COUNT = 12

  class GenerationError < StandardError; end

  def initialize(client: Anthropic::Client.new)
    @client = client
  end

  def generate(description:, mood: nil, genres: [])
    message = @client.messages.create(
      model: MODEL,
      max_tokens: 4096,
      thinking: { type: "adaptive" },
      messages: [{ role: "user", content: build_prompt(description, mood, genres) }]
    )

    parse_tracks(extract_text(message))
  rescue GenerationError
    raise
  rescue => e
    raise GenerationError, "Claude request failed: #{e.message}"
  end

  private

  def build_prompt(description, mood, genres)
    genres = Array(genres).reject(&:blank?)

    <<~PROMPT
      You are an expert music curator. Build a playlist of #{TRACK_COUNT} real,
      existing, well-known songs that fit the situation described below.

      Situation: "#{description}"
      Mood: #{mood.presence || "not specified"}
      Preferred genres: #{genres.any? ? genres.join(", ") : "any"}

      Reason about the activity, the desired energy and tempo, and the mood.
      Prefer songs that are likely available on mainstream streaming services,
      vary the artists, and avoid duplicates.

      Respond with ONLY a JSON array (no markdown fences, no prose) of
      #{TRACK_COUNT} objects, each with exactly these keys:
        {"title": "Song title", "artist": "Artist name"}
    PROMPT
  end

  def extract_text(message)
    blocks = message.respond_to?(:content) ? Array(message.content) : []
    blocks.filter_map do |block|
      type = block.respond_to?(:type) ? block.type : nil
      block.text if [:text, "text"].include?(type) && block.respond_to?(:text)
    end.join("\n")
  end

  def parse_tracks(text)
    cleaned = text.to_s.strip
                  .sub(/\A```(?:json)?\s*/i, "")
                  .sub(/\s*```\z/, "")
                  .strip

    start  = cleaned.index("[")
    finish = cleaned.rindex("]")
    raise GenerationError, "Claude did not return a JSON array" unless start && finish

    data = JSON.parse(cleaned[start..finish])
    raise GenerationError, "Unexpected JSON shape" unless data.is_a?(Array)

    tracks = data.filter_map do |entry|
      next unless entry.is_a?(Hash)

      title  = entry["title"] || entry["name"]
      artist = entry["artist"]
      next if title.blank? || artist.blank?

      { "title" => title.to_s.strip, "artist" => artist.to_s.strip }
    end

    raise GenerationError, "Claude returned no usable tracks" if tracks.empty?

    tracks
  rescue JSON::ParserError => e
    raise GenerationError, "Could not parse Claude response: #{e.message}"
  end
end
