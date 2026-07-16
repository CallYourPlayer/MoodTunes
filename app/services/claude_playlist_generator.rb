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

  def generate(description:, mood: nil, genres: [], exclude: [])
    message = @client.messages.create(
      model: MODEL,
      max_tokens: 4096,
      thinking: { type: "adaptive" },
      messages: [{ role: "user", content: build_prompt(description, mood, genres, exclude) }]
    )

    parse_tracks(extract_text(message))
  rescue GenerationError
    raise
  rescue => e
    raise GenerationError, "Claude request failed: #{e.message}"
  end

  private

  def build_prompt(description, mood, genres, exclude = [])
    genres  = Array(genres).reject(&:blank?)
    exclude = Array(exclude).reject(&:blank?)

    <<~PROMPT
      You are an expert music curator. Build a playlist of #{TRACK_COUNT} real,
      existing songs that fit the situation described below.

      Situation: "#{description}"
      Mood: #{mood.presence || "not specified"}
      Preferred genres: #{genres.any? ? genres.join(", ") : "any"}

      Reason about the activity, the desired energy and tempo, and the mood.
      Favor variety: mix well-known tracks with lesser-known gems and deeper
      cuts, span different artists (no artist twice), and don't default to the
      same handful of obvious hits every time. Every song must still be a real,
      existing track available on mainstream streaming services.
      #{exclusion_block(exclude)}
      Respond with ONLY a JSON array (no markdown fences, no prose) of
      #{TRACK_COUNT} objects, each with exactly these keys:
        {"title": "Song title", "artist": "Artist name"}
    PROMPT
  end

  # When we know which songs recent playlists already used, tell Claude to steer
  # clear of them so playlists stay fresh instead of recycling the same tracks.
  def exclusion_block(exclude)
    return "" if exclude.empty?

    <<~BLOCK

      Do NOT include any of these songs -- they were already used in recent
      playlists, so pick different ones:
      #{exclude.map { |t| "- #{t}" }.join("\n")}
    BLOCK
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
