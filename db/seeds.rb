# Seeds are idempotent and safe to run repeatedly.
#
# They ensure an "owner" account exists and adopt any pre-existing playlists
# that have no owner yet (created before authentication was introduced).
#
# Override the credentials via environment variables when seeding:
#   OWNER_EMAIL=you@example.com OWNER_PASSWORD=secret bin/rails db:seed

owner_email    = ENV.fetch("OWNER_EMAIL", "alfredotorre82@gmail.com").strip.downcase
owner_password = ENV.fetch("OWNER_PASSWORD", "changeme123")

owner = User.find_or_initialize_by(email: owner_email)

if owner.new_record?
  owner.password = owner_password
  owner.save!
  puts "[seeds] Created owner account: #{owner_email}"
  if ENV["OWNER_PASSWORD"].blank?
    puts "[seeds] ⚠️  Default password 'changeme123' used — cambiala al primo accesso!"
  end
else
  puts "[seeds] Owner account already exists: #{owner_email}"
end

# Adopt playlists that predate authentication (user_id IS NULL).
orphans = Playlist.where(user_id: nil)
count   = orphans.update_all(user_id: owner.id)
puts "[seeds] Assigned #{count} orphan playlist(s) to #{owner_email}."
