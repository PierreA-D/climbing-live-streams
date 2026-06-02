# climbing-live-streams

Infrastructure de streaming pour l'écosystème Climbing Live.

Ce dépôt assemble trois briques :

- MediaMTX pour l'ingest, la lecture et l'API de pilotage
- un gateway Nginx pour exposer HLS et WebRTC avec terminaison TLS
- un worker FFmpeg optionnel pour relayer, transcoder ou repackager des flux

## Vue d'ensemble

```text
climbing-live / climbing-live-api
              |
              v
    +-------------------------+
    | climbing-live-streams   |
    |                         |
    |  MediaMTX               |
    |  Nginx gateway          |
    |  FFmpeg worker          |
    +-------------------------+
```

## Services inclus

### MediaMTX

MediaMTX est le coeur du stack. Il expose :

- RTMP sur le port 1935
- RTSP sur le port 8554
- SRT sur le port 8890/udp
- HLS sur le port 8888
- WebRTC sur le port 8889
- l'API HTTP sur le port 9997

La configuration active aussi une authentification HTTP déléguée vers l'application Climbing Live.

### Gateway Nginx

Le gateway publie deux entrées externes :

- 8888 pour HLS en HTTPS
- 8889 pour WebRTC en HTTPS

Les ports 8888 et 8889 terminent TLS avec le certificat monté depuis [certs/mediamtx](certs/mediamtx).

### Worker FFmpeg

Le worker FFmpeg est optionnel et n'est lancé que via le profil Docker Compose `workers`.
Il lit une source et republie vers une cible, typiquement en RTMP.

## Arborescence

```text
.
├── docker-compose.yml
├── gateway/nginx.conf
├── mediamtx/mediamtx.yml
├── ffmpeg/worker.sh
└── certs/mediamtx/
```

## Prérequis

- Docker
- Docker Compose
- un certificat disponible dans [certs/mediamtx](certs/mediamtx) avec les fichiers `server.crt` et `server.key`
- une instance de `climbing-live` accessible depuis les conteneurs sur `host.docker.internal:3000` si l'authentification MediaMTX doit fonctionner

Sous Linux, `host.docker.internal` est mappé via `host-gateway` dans le service MediaMTX.

## Démarrage rapide

Lancer l'infrastructure principale :

```bash
docker compose up -d
```

Vérifier les services :

```bash
docker compose ps
```

Arrêter la stack :

```bash
docker compose down
```

## Production

Le fichier [docker-compose.prod.yml](docker-compose.prod.yml) est la variante recommandée pour une exposition publique.

Il apporte les différences suivantes :

- MediaMTX est piné sur une version explicite
- le gateway Nginx est piné sur une version explicite
- l'API MediaMTX n'est plus publiée sur l'hôte et reste accessible uniquement sur le réseau Docker interne
- des healthchecks sont définis pour MediaMTX et le gateway

Lancer la stack prod :

```bash
docker compose -f docker-compose.prod.yml up -d
```

Mettre à jour la stack prod :

```bash
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## Ports exposés

| Port | Protocole | Usage |
| --- | --- | --- |
| 1935 | TCP | RTMP ingest |
| 8554 | TCP | RTSP ingest/lecture |
| 8890 | UDP | SRT ingest |
| 8189 | UDP | ICE / transport WebRTC |
| 8888 | TCP | HLS via gateway Nginx en HTTPS |
| 8889 | TCP | WebRTC WHEP/WHIP via gateway HTTPS |
| 9997 | TCP | API MediaMTX, uniquement en dev ou sur réseau interne |

## Exemples d'utilisation

### Publier un flux RTMP

```text
rtmp://localhost:1935/live/ma-voie
```

### Lire un flux HLS

```text
https://localhost:8888/live/ma-voie/
```

### Lire ou publier en WebRTC

```text
https://localhost:8889/live/ma-voie/
```

Le chemin exact dépend du client utilisé, mais toutes les URLs WebRTC passent par le gateway TLS sur 8889.

## Worker FFmpeg

Le worker reste inactif tant que `SOURCE_URL` et `TARGET_URL` ne sont pas fournis.

Exemple de lancement :

```bash
SOURCE_URL=rtmp://mediamtx:1935/live/source \
TARGET_URL=rtmp://mediamtx:1935/live/output \
docker compose --profile workers up -d ffmpeg-worker
```

Variables disponibles :

- `SOURCE_URL` : source en entrée, obligatoire
- `TARGET_URL` : destination en sortie, obligatoire
- `VIDEO_CODEC` : codec vidéo FFmpeg, `copy` par défaut
- `AUDIO_CODEC` : codec audio FFmpeg, `aac` par défaut

Le script exécuté par le conteneur est défini dans [ffmpeg/worker.sh](ffmpeg/worker.sh).

## Authentification MediaMTX

MediaMTX délègue l'autorisation à l'endpoint suivant :

```text
http://host.docker.internal:3000/api/internal/mediamtx/auth
```

Les actions `api`, `metrics` et `pprof` sont exclues de cette auth HTTP.

Champs transmis à l'endpoint d'auth :

- `user`
- `password`
- `token`
- `ip`
- `action`
- `path`
- `protocol`
- `id`
- `query`

Le User-Agent du navigateur n'est pas transmis par MediaMTX. Si un filtrage dépend du client HTTP, il doit être fait ailleurs, ou remplacé par une logique à base de token ou JWT.

## Intégration avec climbing-live

Variables utiles côté application :

- `MEDIAMTX_API_URL=http://host.docker.internal:9997` pour piloter MediaMTX depuis un conteneur applicatif
- `HLS_BASE_URL=https://localhost:8888` pour construire les URLs lues par le navigateur
- base WebRTC via `https://<host>:8889`

Si le front tourne hors Docker, adaptez les hôtes en conséquence.

En prod, si un autre service doit consommer l'API MediaMTX, il doit rejoindre le même réseau Docker et utiliser `http://mediamtx:9997` au lieu d'un port publié sur l'hôte.

## Fichiers importants

- [docker-compose.yml](docker-compose.yml) : définition des services
- [mediamtx/mediamtx.yml](mediamtx/mediamtx.yml) : configuration MediaMTX
- [gateway/nginx.conf](gateway/nginx.conf) : reverse proxy HLS et WebRTC
- [ffmpeg/worker.sh](ffmpeg/worker.sh) : commande de relay/transcodage FFmpeg

## Dépannage rapide

- Si HLS ou WebRTC ne fonctionnent pas, vérifier la présence et la validité du certificat dans [certs/mediamtx](certs/mediamtx).
- Les healthchecks du gateway utilisent `https://127.0.0.1:8888/healthz`; si vous remplacez le fichier [gateway/nginx.conf](gateway/nginx.conf), conservez cette route.
- Si l'auth MediaMTX échoue, vérifier que `climbing-live` répond bien sur `http://host.docker.internal:3000` depuis le conteneur.
- Si le worker FFmpeg semble bloqué, vérifier que `SOURCE_URL` et `TARGET_URL` sont renseignés.