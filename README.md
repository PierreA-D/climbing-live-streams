# climbing-live-streams

Infrastructure streaming dédiée pour l'écosystème Climbing Live.

## Stack

- MediaMTX (ingest RTMP/RTSP/SRT + API)
- Gateway WebRTC/HLS (Nginx)
- Workers FFmpeg (transcode/repackage)

## Architecture

```text
climbing-live (Next.js)
        ↓
climbing-live-api (Symfony)
        ↓
climbing-live-streams
     ├── MediaMTX
     ├── FFmpeg workers
     └── WebRTC/HLS gateway
```

## Démarrage

```bash
docker compose up -d
```

Ports exposés:

- 1935 (RTMP)
- 8554 (RTSP)
- 8890/udp (SRT)
- 8189/udp (WebRTC ICE)
- 8888 (HLS via gateway)
- 8889 (WebRTC HTTP via gateway)
- 9997 (API MediaMTX)

## Worker FFmpeg

Le service FFmpeg est optionnel (profil `workers`).

Exemple:

```bash
SOURCE_URL=rtmp://mediamtx:1935/input \
TARGET_URL=rtmp://mediamtx:1935/output \
docker compose --profile workers up -d ffmpeg-worker
```

Variables disponibles:

- `SOURCE_URL` (obligatoire)
- `TARGET_URL` (obligatoire)
- `VIDEO_CODEC` (défaut: `copy`)
- `AUDIO_CODEC` (défaut: `aac`)

## Intégration avec climbing-live

Dans `climbing-live`, configurer:

- `MEDIAMTX_API_URL=http://host.docker.internal:9997` pour le conteneur Next.js
- `HLS_BASE_URL=http://localhost:8888` pour les URLs lues par le navigateur

MediaMTX appelle l'endpoint d'auth du front:

- `http://host.docker.internal:3000/api/internal/mediamtx/auth`