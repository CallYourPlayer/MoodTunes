class CreatePlaylists < ActiveRecord::Migration[7.1]
  def change
    create_table :playlists do |t|
      t.string  :title,       null: false
      t.text    :description, null: false
      t.string  :mood
      t.jsonb   :genres,      null: false, default: []
      t.jsonb   :tracks,      null: false, default: []
      t.string  :slug,        null: false

      t.timestamps
    end

    add_index :playlists, :slug, unique: true
  end
end
