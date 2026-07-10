# Thin wrapper around the YouTube Data API v3 search endpoint.
# https://developers.google.com/youtube/v3/docs/search/list
#
# Requires a server-side API key in ENV["YOUTUBE_API_KEY"] (no OAuth needed:
# we only read public search results, we don't touch a user's account).
#
# Quota note: search.list costs 100 units and the free daily quota is 10,000
# units, so results are cached to avoid burning quota on repeated queries.
class YoutubeClient
  include HTTParty
  base_uri "https://www.googleapis.com/youtube/v3"
  default_timeout 8

  MUSIC_CATEGORY_ID = "10".freeze

  # Resolve a single suggested song (title + artist) to a concrete YouTube video.
  def search_track(title:, artist:)
    search("#{title} #{artist}", limit: 1).first
  end

  # Free-text search used by the live "add track" box.
  def search(query, limit: 10)
    query = query.to_s.strip
    return [] if query.blank?

    Rails.cache.fetch("yt:#{query.downcase}:#{limit}", expires_in: 12.hours) do
      get_search(query, limit: limit)
    end
  end

  private

  def get_search(query, limit:)
    api_key = ENV["YOUTUBE_API_KEY"]
    if api_key.blank?
      Rails.logger.warn("[YoutubeClient] YOUTUBE_API_KEY is not set")
      return []
    end

    response = self.class.get("/search", query: {
      key:             api_key,
      q:               query,
      part:            "snippet",
      type:            "video",
      videoEmbeddable: "true",
      videoCategoryId: MUSIC_CATEGORY_ID,
      maxResults:      limit
    })

    body  = response.parsed_response
    items = body.is_a?(Hash) ? body["items"] : nil

    Array(items).filter_map { |item| to_track(item) }
  rescue => e
    Rails.logger.warn("[YoutubeClient] search failed: #{e.class}: #{e.message}")
    []
  end

  def to_track(item)
    return nil unless item.is_a?(Hash)

    video_id = item.dig("id", "videoId")
    snippet  = item["snippet"]
    return nil unless video_id && snippet.is_a?(Hash)

    thumbnails = snippet["thumbnails"] || {}
    thumbnail  = thumbnails.dig("medium", "url") || thumbnails.dig("default", "url")

    {
      "title"       => decode_entities(snippet["title"]),
      "artist"      => clean_channel(snippet["channelTitle"]),
      "youtube_id"  => video_id,
      "youtube_url" => "https://www.youtube.com/watch?v=#{video_id}",
      "thumbnail"   => thumbnail
    }
  end

  # YouTube "auto-generated" music channels are named "<Artist> - Topic".
  def clean_channel(name)
    name.to_s.sub(/\s*-\s*Topic\z/, "").strip
  end

  # YouTube titles come HTML-escaped (e.g. &amp;, &quot;).
  def decode_entities(text)
    CGI.unescapeHTML(text.to_s)
  end
end
