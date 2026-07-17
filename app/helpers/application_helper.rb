module ApplicationHelper
  # Social share targets for a public playlist page. Each entry is a label plus
  # an intent URL that opens the network's pre-filled share dialog. All targets
  # rely only on the public slug URL, so they work for logged-out visitors too.
  def playlist_share_links(playlist)
    url  = playlist_url(playlist)
    text = "#{playlist.title} · una playlist su MoodTunes"

    [
      { label: "WhatsApp", url: "https://wa.me/?text=#{share_encode("#{text} #{url}")}" },
      { label: "X",        url: "https://twitter.com/intent/tweet?text=#{share_encode(text)}&url=#{share_encode(url)}" },
      { label: "Facebook", url: "https://www.facebook.com/sharer/sharer.php?u=#{share_encode(url)}" },
      { label: "Telegram", url: "https://t.me/share/url?url=#{share_encode(url)}&text=#{share_encode(text)}" }
    ]
  end

  # First available track thumbnail, used as the Open Graph / Twitter preview
  # image. Returns nil when no track has a thumbnail.
  def playlist_share_image(playlist)
    playlist.track_list.map { |track| track["thumbnail"] }.compact_blank.first
  end

  private

  def share_encode(value)
    CGI.escape(value.to_s)
  end
end
