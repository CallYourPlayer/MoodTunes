# 🎧 MoodTunes

Genera playlist musicali a partire dalla descrizione di una situazione
(es. _"lavoro al pc"_, _"corsa"_, _"viaggio in macchina"_), con un mood e dei
generi opzionali. Claude interpreta il contesto e propone 10–15 brani; ogni brano
viene risolto sulla **Deezer Search API** per recuperare copertina, link e
anteprima di 30 secondi. Ogni playlist ha una pagina pubblica condivisibile.

## Stack tecnico

- **Ruby on Rails 7.1** (PostgreSQL, Puma)
- **Tailwind CSS** (`tailwindcss-rails`, nessun Node richiesto)
- **importmap-rails** + JavaScript vanilla + **SortableJS** (drag & drop)
- **Anthropic Ruby SDK** — modello `claude-sonnet-4-6`
- **HTTParty** — chiamate alla Deezer Search API (senza autenticazione)
- **Docker Compose** (Rails + PostgreSQL)
- Deploy su **Render** (`render.yaml`)

## Funzionalità

- Homepage con descrizione libera + mood (felice, concentrato, energico,
  rilassato, malinconico) + generi (pop, rock, jazz, elettronica, hip-hop, classica).
- Generazione playlist via Claude → risoluzione brani su Deezer.
- Pagina pubblica `/playlists/:slug` con copertine, titoli, artisti, anteprima
  e link a Deezer.
- **Rigenera playlist**: riusa descrizione e mood originali, richiama Claude e
  sostituisce i brani mantenendo lo stesso slug/URL.
- **Aggiungi brani**: ricerca live su Deezer mentre scrivi, aggiunta con un click.
- **Rimuovi brani**: pulsante per ogni brano.
- **Drag & drop** per riordinare, con salvataggio immediato nel database.
- Nessuna autenticazione utente.

---

## Avvio con Docker (consigliato)

Prerequisiti: Docker + Docker Compose.

```bash
# 1. Configura le variabili d'ambiente
cp .env.example .env
#    poi modifica .env e inserisci la tua ANTHROPIC_API_KEY

# 2. Avvia (build immagine + Postgres + migrazioni + build Tailwind)
docker compose up --build
```

L'app sarà disponibile su **http://localhost:3000**.

L'entrypoint del container esegue automaticamente:
`bundle install` (se serve) → `rails db:prepare` → `rails tailwindcss:build` → avvio Puma.

Comandi utili:

```bash
docker compose exec web bin/rails console
docker compose exec web bin/rails db:migrate
docker compose down            # ferma i container
docker compose down -v         # ferma e cancella anche il volume del DB
```

---

## Avvio in locale (senza Docker)

Prerequisiti: Ruby 3.3.6, PostgreSQL in esecuzione.

```bash
bundle install

export ANTHROPIC_API_KEY=sk-ant-...
# Adatta l'host del DB (di default punta a "db" per Docker):
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/moodtunes_development

bin/rails db:prepare
bin/rails tailwindcss:build      # oppure: bin/rails tailwindcss:watch in un altro terminale
bin/rails server
```

---

## Variabili d'ambiente

| Variabile                 | Dove                   | Descrizione                                              |
| ------------------------- | ---------------------- | -------------------------------------------------------- |
| `ANTHROPIC_API_KEY`       | sempre                 | Chiave API Anthropic (Claude). **Obbligatoria.**         |
| `DATABASE_URL`            | sempre                 | Connessione PostgreSQL.                                  |
| `SECRET_KEY_BASE`         | produzione             | Segreto Rails (generato automaticamente su Render).      |
| `RAILS_SERVE_STATIC_FILES`| produzione             | `true` per servire gli asset compilati.                  |
| `RAILS_LOG_TO_STDOUT`     | produzione             | `true` per loggare su stdout.                            |
| `WEB_CONCURRENCY`         | produzione (opzionale) | Numero di worker Puma.                                   |

> Nota: il progetto **non** usa `config/credentials.yml.enc` né `master.key`.
> In produzione il segreto arriva da `SECRET_KEY_BASE`.

---

## Deploy su Render

Il file [`render.yaml`](./render.yaml) è un Blueprint che crea due risorse:
un **web service Rails** e un **database PostgreSQL** gestito.

### Passi

1. Fai push del repository su GitHub/GitLab.
2. Su Render: **New → Blueprint**, seleziona il repository. Render leggerà
   `render.yaml` e proporrà la creazione del web service + database.
3. **Imposta le variabili d'ambiente** del web service `moodtunes`:
   - `ANTHROPIC_API_KEY` → incolla la tua chiave (è marcata `sync: false`,
     quindi va inserita a mano nel dashboard per sicurezza).
   - `DATABASE_URL` → **collegata automaticamente** al database `moodtunes-db`
     tramite il blocco `fromDatabase` (nessuna azione manuale).
   - `SECRET_KEY_BASE` → **generata automaticamente** (`generateValue: true`).
   - Le altre (`RAILS_ENV`, `RAILS_SERVE_STATIC_FILES`, `RAILS_LOG_TO_STDOUT`,
     `WEB_CONCURRENCY`) sono già definite nel blueprint.
4. Avvia il deploy. Render esegue:
   - **build**: `bundle install && rails assets:precompile && rails assets:clean`
     (la precompilazione genera anche il CSS Tailwind).
   - **start**: `rails db:migrate && puma -C config/puma.rb`
     (le migrazioni vengono applicate a ogni deploy).

### Impostare/aggiornare una variabile manualmente

Render Dashboard → servizio **moodtunes** → **Environment** → **Add/Edit
Environment Variable** → salva (il servizio viene ridistribuito).

---

## Modello dati

`Playlist`:

| Campo         | Tipo    | Note                                             |
| ------------- | ------- | ------------------------------------------------ |
| `title`       | string  | Titolo derivato dalla descrizione + mood.        |
| `description` | text    | Descrizione originale dell'utente.               |
| `mood`        | string  | Mood opzionale.                                  |
| `genres`      | jsonb   | Array di generi selezionati.                     |
| `tracks`      | jsonb   | Array di brani (titolo, artista, dati Deezer).   |
| `slug`        | string  | Identificatore univoco condivisibile (URL).      |
| timestamps    |         | `created_at`, `updated_at`.                      |

Ogni brano in `tracks` ha: `uid`, `position`, `title`, `artist`, `deezer_id`,
`deezer_url`, `cover`, `preview`. Lo `uid` è una chiave stabile usata da
rimozione e riordino.

## Endpoint principali

| Metodo | Path                              | Descrizione                          |
| ------ | --------------------------------- | ------------------------------------ |
| GET    | `/`                               | Homepage con il form.                |
| POST   | `/playlists`                      | Genera e salva una playlist.         |
| GET    | `/playlists/:slug`                | Pagina pubblica della playlist.      |
| POST   | `/playlists/:slug/regenerate`     | Rigenera i brani (stesso slug).      |
| POST   | `/playlists/:slug/add_track`      | Aggiunge un brano (AJAX).            |
| DELETE | `/playlists/:slug/remove_track`   | Rimuove un brano (AJAX, `?uid=`).    |
| PATCH  | `/playlists/:slug/reorder`        | Salva il nuovo ordine (AJAX).        |
| GET    | `/deezer/search?q=...`            | Proxy ricerca Deezer (JSON).         |
