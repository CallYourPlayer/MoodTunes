class User < ApplicationRecord
  has_secure_password

  has_many :playlists, dependent: :nullify

  # Store emails normalized so lookups and uniqueness are case-insensitive.
  before_validation :normalize_email

  EMAIL_REGEX = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  validates :email,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: EMAIL_REGEX, message: "non è un indirizzo valido" }
  validates :password, length: { minimum: 8 }, allow_nil: true

  private

  def normalize_email
    self.email = email.to_s.strip.downcase.presence
  end
end
