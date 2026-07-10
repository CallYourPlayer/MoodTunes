import Sortable from "sortablejs"

function csrfToken() {
  return document.querySelector('meta[name="csrf-token"]')?.content || ""
}

function jsonHeaders() {
  return { "Content-Type": "application/json", "X-CSRF-Token": csrfToken() }
}

// Disable the generate button on submit so the user knows work is happening.
function initGenerateForm() {
  const form = document.querySelector("[data-generate-form]")
  if (!form) return
  form.addEventListener("submit", () => {
    const btn = form.querySelector("[data-submit]")
    if (btn) {
      btn.disabled = true
      btn.textContent = "Generazione in corso..."
    }
  })
}

function updateTrackCount(root) {
  const count = root.querySelectorAll("[data-track-list] [data-uid]").length
  const el = root.querySelector("[data-track-count]")
  if (el) el.textContent = count
}

function initPlaylist() {
  const root = document.querySelector("[data-playlist]")
  if (!root) return

  const slug = root.dataset.playlist
  const list = root.querySelector("[data-track-list]")
  const searchInput = root.querySelector("[data-search-input]")
  const resultsBox = root.querySelector("[data-search-results]")

  const player = createPlayer(root, list)

  // --- Drag & drop reorder ---
  if (list) {
    Sortable.create(list, {
      handle: "[data-drag-handle]",
      animation: 150,
      onEnd: () => {
        const order = [...list.querySelectorAll("[data-uid]")].map((el) => el.dataset.uid)
        fetch(`/playlists/${slug}/reorder`, {
          method: "PATCH",
          headers: jsonHeaders(),
          body: JSON.stringify({ order }),
        })
      },
    })

    // --- Play / Remove (event delegation) ---
    list.addEventListener("click", (e) => {
      const playBtn = e.target.closest("[data-play]")
      if (playBtn) {
        player.play(playBtn.closest("[data-uid]"))
        return
      }

      const removeBtn = e.target.closest("[data-remove]")
      if (!removeBtn) return
      const li = removeBtn.closest("[data-uid]")
      const uid = li.dataset.uid
      fetch(`/playlists/${slug}/remove_track?uid=${encodeURIComponent(uid)}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": csrfToken() },
      }).then((res) => {
        if (res.ok) {
          player.notifyRemoved(li)
          li.remove()
          updateTrackCount(root)
        }
      })
    })
  }

  // --- Live YouTube search ---
  if (searchInput && resultsBox) {
    let timer
    searchInput.addEventListener("input", () => {
      clearTimeout(timer)
      const q = searchInput.value.trim()
      if (q.length < 2) {
        resultsBox.innerHTML = ""
        return
      }
      timer = setTimeout(() => runSearch(q, resultsBox, slug, list, root, searchInput), 300)
    })
  }
}

function runSearch(q, resultsBox, slug, list, root, searchInput) {
  fetch(`/youtube/search?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
    .then((res) => res.json())
    .then(({ results }) => {
      resultsBox.innerHTML = ""
      if (!results || results.length === 0) {
        resultsBox.innerHTML =
          '<p class="px-2 py-2 text-sm text-white/40">Nessun risultato.</p>'
        return
      }
      results.forEach((track) => {
        resultsBox.appendChild(buildResult(track, slug, list, root, resultsBox, searchInput))
      })
    })
    .catch(() => {
      resultsBox.innerHTML =
        '<p class="px-2 py-2 text-sm text-red-300">Errore nella ricerca.</p>'
    })
}

function buildResult(track, slug, list, root, resultsBox, searchInput) {
  const btn = document.createElement("button")
  btn.type = "button"
  btn.className =
    "flex w-full items-center gap-3 rounded-lg border border-white/10 bg-slate-900/60 px-3 py-2 text-left transition hover:border-indigo-400 hover:bg-indigo-500/10"

  const img = document.createElement("img")
  img.src = track.thumbnail || ""
  img.alt = ""
  img.className = "h-10 w-10 flex-none rounded object-cover bg-slate-800"

  const info = document.createElement("div")
  info.className = "min-w-0 flex-1"
  const title = document.createElement("p")
  title.className = "truncate text-sm font-medium"
  title.textContent = track.title || ""
  const artist = document.createElement("p")
  artist.className = "truncate text-xs text-white/50"
  artist.textContent = track.artist || ""
  info.append(title, artist)

  const plus = document.createElement("span")
  plus.className = "flex-none text-indigo-300"
  plus.textContent = "+ Aggiungi"

  btn.append(img, info, plus)
  btn.addEventListener("click", () => {
    addTrack(track, slug, list, root)
    resultsBox.innerHTML = ""
    if (searchInput) searchInput.value = ""
  })
  return btn
}

function addTrack(track, slug, list, root) {
  fetch(`/playlists/${slug}/add_track`, {
    method: "POST",
    headers: jsonHeaders(),
    body: JSON.stringify({
      track: {
        title: track.title,
        artist: track.artist,
        youtube_id: track.youtube_id,
        youtube_url: track.youtube_url,
        thumbnail: track.thumbnail,
      },
    }),
  })
    .then((res) => res.text())
    .then((html) => {
      if (list) {
        list.insertAdjacentHTML("beforeend", html)
        updateTrackCount(root)
      }
    })
}

// --- Continuous YouTube player (IFrame API) ---------------------------------
//
// A single sticky mini-player plays the current track; when a video ends it
// advances to the next <li> in the CURRENT DOM order, so drag & drop and
// removals are always respected.
function createPlayer(root, list) {
  const bar = root.querySelector("[data-yt-player]")
  const titleEl = root.querySelector("[data-yt-title]")
  const artistEl = root.querySelector("[data-yt-artist]")
  const closeBtn = root.querySelector("[data-yt-close]")

  let yt = null // the YT.Player instance
  let ready = false
  let pendingUid = null // uid requested before the API finished loading
  let currentUid = null

  loadIframeApi(() => {
    yt = new YT.Player("yt-frame", {
      width: "100%",
      height: "100%",
      playerVars: { autoplay: 1, playsinline: 1, rel: 0 },
      events: {
        onReady: () => {
          ready = true
          if (pendingUid) {
            const li = liByUid(pendingUid)
            pendingUid = null
            if (li) start(li)
          }
        },
        onStateChange: (e) => {
          if (e.data === YT.PlayerState.ENDED) playNext()
        },
      },
    })
  })

  function liByUid(uid) {
    return list?.querySelector(`[data-uid="${CSS.escape(uid)}"]`)
  }

  function trackMeta(li) {
    const info = li.querySelector(".min-w-0")
    const ps = info ? info.querySelectorAll("p") : []
    return { title: ps[0]?.textContent || "", artist: ps[1]?.textContent || "" }
  }

  function highlight(li) {
    list?.querySelectorAll("[data-playing]").forEach((el) => {
      el.removeAttribute("data-playing")
      el.classList.remove("ring-2", "ring-indigo-400")
    })
    if (li) {
      li.setAttribute("data-playing", "true")
      li.classList.add("ring-2", "ring-indigo-400")
    }
  }

  function start(li) {
    const videoId = li.dataset.youtubeId
    if (!videoId) return
    currentUid = li.dataset.uid
    const meta = trackMeta(li)
    if (titleEl) titleEl.textContent = meta.title
    if (artistEl) artistEl.textContent = meta.artist
    highlight(li)
    bar?.classList.remove("hidden")
    yt.loadVideoById(videoId)
  }

  function playNext() {
    const cur = currentUid ? liByUid(currentUid) : null
    let next = cur?.nextElementSibling
    while (next && !next.dataset?.youtubeId) next = next.nextElementSibling
    if (next) start(next)
  }

  function close() {
    if (yt && ready) yt.stopVideo()
    currentUid = null
    highlight(null)
    bar?.classList.add("hidden")
  }

  closeBtn?.addEventListener("click", close)

  return {
    play(li) {
      if (!li) return
      if (!ready || !yt) {
        pendingUid = li.dataset.uid
        return
      }
      start(li)
    },
    // Keep playback sensible if the currently playing track is removed.
    notifyRemoved(li) {
      if (li.dataset.uid !== currentUid) return
      const next = li.nextElementSibling
      if (yt && ready && next && next.dataset.youtubeId) {
        start(next)
      } else if (yt && ready) {
        yt.stopVideo()
        currentUid = null
        highlight(null)
        bar?.classList.add("hidden")
      }
    },
  }
}

let iframeApiRequested = false
function loadIframeApi(onReady) {
  const callbacks = (loadIframeApi._callbacks ||= [])
  callbacks.push(onReady)

  if (window.YT && window.YT.Player) {
    callbacks.splice(0).forEach((cb) => cb())
    return
  }

  const prev = window.onYouTubeIframeAPIReady
  window.onYouTubeIframeAPIReady = () => {
    if (typeof prev === "function") prev()
    ;(loadIframeApi._callbacks || []).splice(0).forEach((cb) => cb())
  }

  if (iframeApiRequested) return
  iframeApiRequested = true
  const tag = document.createElement("script")
  tag.src = "https://www.youtube.com/iframe_api"
  document.head.appendChild(tag)
}

document.addEventListener("DOMContentLoaded", () => {
  initGenerateForm()
  initPlaylist()
})
