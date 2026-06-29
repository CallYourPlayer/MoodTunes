# Thin wrapper around the public Deezer Search API (no authentication required).
# https://api.deezer.com/search
class DeezerClient
  include HTTParty
  base_uri "https://api.deezer.com"
  default_timeout 8

  # Resolve a single suggested song (title + artist) to a concrete Deezer track.
  # Tries a strict field query first, then falls back to a loose query.
  def search_track(title:, artist:)
    strict = get_search(%(track:"#{title}" artist:"#{artist}"), limit: 1)
    return strict.first if strict.any?

    get_search("#{title} #{artist}", limit: 1).first
  end

  # Free-text search used by the live "add track" box.
  def search(query, limit: 10)
    return [] if query.to_s.strip.blank?

    get_search(query, limit: limit)
  end

  private

  def get_search(query, limit:)
    response = self.class.get("/search", query: { q: query, limit: limit })
    body     = response.parsed_response
    data     = body.is_a?(Hash) ? body["data"] : nil

    Array(data).filter_map { |item| to_track(item) }
  rescue => e
    Rails.logger.warn("[DeezerClient] search failed: #{e.class}: #{e.message}")
    []
  end

  def to_track(item)
    return nil unless item.is_a?(Hash)

    {
      "title"      => item["title"],
      "artist"     => item.dig("artist", "name"),
      "deezer_id"  => item["id"],
      "deezer_url" => item["link"],
      "cover"      => item.dig("album", "cover_medium") || item.dig("album", "cover"),
      "preview"    => item["preview"]
    }
  end
end
