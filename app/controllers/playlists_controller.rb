class PlaylistsController < ApplicationController
  before_action :set_playlist, only: %i[show regenerate add_track remove_track reorder destroy]

  # GET /playlists
  def index
    @playlists = Playlist.order(created_at: :desc)
  end

  # POST /playlists
  def create
    description = params[:description].to_s.strip
    mood        = params[:mood].presence
    genres      = Array(params[:genres]).reject(&:blank?)

    if description.blank?
      redirect_to root_path, alert: "Descrivi la situazione per generare una playlist." and return
    end

    suggestions = ClaudePlaylistGenerator.new.generate(description: description, mood: mood, genres: genres)
    tracks      = build_tracks(suggestions)

    if tracks.empty?
      redirect_to root_path, alert: "Non sono riuscito a trovare i brani su YouTube. Riprova." and return
    end

    playlist = Playlist.create!(
      title:       derive_title(description, mood),
      description: description,
      mood:        mood,
      genres:      genres,
      tracks:      tracks
    )

    redirect_to playlist_path(playlist)
  rescue ClaudePlaylistGenerator::GenerationError => e
    Rails.logger.error("[Playlists#create] #{e.message}")
    redirect_to root_path, alert: "Generazione non riuscita: #{e.message}"
  rescue => e
    Rails.logger.error("[Playlists#create] #{e.class}: #{e.message}")
    redirect_to root_path, alert: "Si è verificato un errore imprevisto. Riprova."
  end

  # GET /playlists/:slug
  def show
  end

  # DELETE /playlists/:slug
  def destroy
    @playlist.destroy
    redirect_to playlists_path, notice: "Playlist eliminata."
  end

  # POST /playlists/:slug/regenerate
  def regenerate
    suggestions = ClaudePlaylistGenerator.new.generate(
      description: @playlist.description,
      mood:        @playlist.mood,
      genres:      @playlist.genres
    )
    tracks = build_tracks(suggestions)

    if tracks.any?
      @playlist.update!(tracks: tracks)
      redirect_to playlist_path(@playlist), notice: "Playlist rigenerata."
    else
      redirect_to playlist_path(@playlist), alert: "Nessun brano trovato durante la rigenerazione."
    end
  rescue ClaudePlaylistGenerator::GenerationError => e
    Rails.logger.error("[Playlists#regenerate] #{e.message}")
    redirect_to playlist_path(@playlist), alert: "Rigenerazione non riuscita: #{e.message}"
  end

  # POST /playlists/:slug/add_track
  def add_track
    track = track_params.to_h.stringify_keys
    track["uid"] = SecureRandom.hex(8)

    updated = reindex(@playlist.track_list + [track])
    @playlist.update!(tracks: updated)

    render partial: "playlists/track", locals: { track: updated.last, playlist: @playlist }
  end

  # DELETE /playlists/:slug/remove_track?uid=...
  def remove_track
    uid     = params[:uid].to_s
    updated = reindex(@playlist.track_list.reject { |t| t["uid"] == uid })
    @playlist.update!(tracks: updated)

    head :no_content
  end

  # PATCH /playlists/:slug/reorder  { order: [uid, uid, ...] }
  def reorder
    order  = Array(params[:order]).map(&:to_s)
    by_uid = @playlist.track_list.index_by { |t| t["uid"] }

    ordered  = order.filter_map { |uid| by_uid[uid] }
    ordered += @playlist.track_list.reject { |t| order.include?(t["uid"]) }

    @playlist.update!(tracks: reindex(ordered))
    head :no_content
  end

  private

  def set_playlist
    @playlist = Playlist.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: "Playlist non trovata." and return
  end

  def track_params
    params.require(:track).permit(:title, :artist, :youtube_id, :youtube_url, :thumbnail)
  end

  # Resolve each suggested {title, artist} to a YouTube video, attaching a
  # stable uid and position so the front-end can reorder/remove reliably.
  def build_tracks(suggestions)
    youtube = YoutubeClient.new

    resolved = suggestions.filter_map do |s|
      found = youtube.search_track(title: s["title"], artist: s["artist"])
      next unless found && found["youtube_id"]

      found.merge("uid" => SecureRandom.hex(8))
    end

    reindex(resolved)
  end

  def reindex(tracks)
    tracks.each_with_index.map { |t, i| t.merge("position" => i) }
  end

  def derive_title(description, mood)
    base = description.split.first(6).join(" ").strip
    base = base[0, 60].presence || "Playlist"
    mood.present? ? "#{base.capitalize} · #{mood.capitalize}" : base.capitalize
  end
end
