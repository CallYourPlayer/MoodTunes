class Playlist < ApplicationRecord
  MOODS  = %w[felice concentrato energico rilassato malinconico].freeze
  GENRES = %w[pop rock jazz elettronica hip-hop classica].freeze

  # Optional so historical playlists without an owner keep working; new
  # playlists are always created through an authenticated user.
  belongs_to :user, optional: true

  before_validation :assign_slug, on: :create

  validates :title, presence: true
  validates :description, presence: true
  validates :slug, presence: true, uniqueness: true

  # Use the slug in URLs (playlist_path(playlist) => /playlists/:slug).
  def to_param
    slug
  end

  # Tracks are stored as an array of hashes (jsonb). Always return an Array.
  def track_list
    Array(tracks)
  end

  private

  def assign_slug
    return if slug.present?

    loop do
      self.slug = SecureRandom.alphanumeric(10).downcase
      break unless self.class.exists?(slug: slug)
    end
  end
end
