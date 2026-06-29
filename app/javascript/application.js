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

    // --- Remove (event delegation) ---
    list.addEventListener("click", (e) => {
      const btn = e.target.closest("[data-remove]")
      if (!btn) return
      const li = btn.closest("[data-uid]")
      const uid = li.dataset.uid
      fetch(`/playlists/${slug}/remove_track?uid=${encodeURIComponent(uid)}`, {
        method: "DELETE",
        headers: { "X-CSRF-Token": csrfToken() },
      }).then((res) => {
        if (res.ok) {
          li.remove()
          updateTrackCount(root)
        }
      })
    })
  }

  // --- Live Deezer search ---
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
  fetch(`/deezer/search?q=${encodeURIComponent(q)}`, { headers: { Accept: "application/json" } })
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
  img.src = track.cover || ""
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
        deezer_id: track.deezer_id,
        deezer_url: track.deezer_url,
        cover: track.cover,
        preview: track.preview,
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

document.addEventListener("DOMContentLoaded", () => {
  initGenerateForm()
  initPlaylist()
})
