class AddUserToPlaylists < ActiveRecord::Migration[7.1]
  def change
    # Nullable so pre-existing playlists survive the migration; the owner is
    # backfilled by db/seeds.rb (assigned to the first/owner account).
    add_reference :playlists, :user, null: true, foreign_key: true
  end
end
