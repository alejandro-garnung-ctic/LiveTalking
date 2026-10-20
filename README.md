# Integración con ctic-jAnItor / PorterIA (avatar de vídeo)

Este fork añade lo necesario para usar LiveTalking como **avatar de vídeo con
lipsync** dentro del flujo de voz de ctic-jAnItor, sustituyendo el render 3D de
TalkingHead sin cambiar el resto del pipeline (STT → LLM → TTS).

### 1. `AVATAR_VIDEO_DELAY_MS` (retardo de vídeo)

El vídeo va ligeramente por delante del audio en el navegador (latencia del
altavoz), lo que descuadra el lipsync. `server/webrtc.py` acepta:

```bash
AVATAR_VIDEO_DELAY_MS=120 python app.py --transport webrtc --model wav2lip \
  --avatar_id turin9 --listenport 8020 --max_session 0
```

- `0` (por defecto): sin retardo.
- `120`: valor recomendado en la máquina de pruebas. Ajustar entre `80` y `180`:
  si el audio suena **después** del movimiento, súbelo; si suena **antes**,
  bájalo.

### 2. Lanzar a mano (simple)

```bash
cd /opt/livetalking
AVATAR_VIDEO_DELAY_MS=120 .venv/bin/python app.py --transport webrtc \
  --model wav2lip --avatar_id turin9 --listenport 8020 --max_session 0
```

- `--max_session 0` (o negativo) desactiva el límite de sesiones concurrentes;
  también es el valor por defecto. Si se omite, no hay límite.
- Cada reintento del navegador crea una sesión. Con el límite antiguo (5) los
  reintentos lo llenaban y bloqueaban la conexión con
  `Maximum session limit reached (5/5)`; por eso conviene dejarlo ilimitado.

### 3. Arranque condicional con systemd

`deploy/run-if-enabled.sh` solo arranca LiveTalking si
`AVATAR_UI_MODE=livetalking` en el `.env` de ctic-jAnItor; en cualquier otro
modo sale con código 0 (systemd no lo reinicia).

```bash
sudo cp deploy/livetalking.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable livetalking.service
sudo systemctl start livetalking.service
```

- `.env` por defecto: `/opt/ctic-jAnItor/.env` (configurable con
  `LIVETALKING_ENV_FILE`).
- Variables leídas: `AVATAR_UI_MODE`, `LIVETALKING_AVATAR`,
  `AVATAR_VIDEO_DELAY_MS`, `LIVETALKING_PORT`,
  `LIVETALKING_MAX_SESSION` (`0` = ilimitado, por defecto).
- Cambiar de modo: editar `AVATAR_UI_MODE` y `sudo systemctl restart livetalking`.
- Logs: `journalctl -u livetalking -f`.

### 4. Integración con el embed web (`avatar-live`)

En ctic-jAnItor, el servicio `avatar-live` recibe texto, sintetiza con LiteLLM
(`POST /v1/audio/speech`) y reenvía el WAV a `LiveTalking /humanaudio`. El iframe
(`avatar-3d`, modo `livetalking`) conecta por WebRTC y reproduce el vídeo. Ver
`services/avatar-live/README.md` en ctic-jAnItor.

### 5. Requisitos

- GPU NVIDIA (probado en RTX PRO 2000 Blackwell, 8 GB) con `torch` cu128.
- `models/wav2lip.pth` y avatar en `data/avatars/<avatar_id>/`.
- Puerto `8020` accesible desde el navegador (WebRTC).

### 6. Subir un nuevo avatar

La forma más sencilla es la **web de generación de avatares**:

```
http://<host>:<listenport>/avatar-en.html   # inglés
http://<host>:<listenport>/avatar.html      # chino
```

Ejemplo: <http://localhost:8020/avatar-en.html>. Sube el vídeo, indica el
`avatar_id`, elige `wav2lip`/`musetalk` y lanza la generación.

También puedes hacerlo por API:

```
POST http://<host>:<listenport>/api/avatar/task
```

Es **multipart/form-data** (o JSON con `video_path` si el vídeo ya está en el
servidor). Ejemplo con `curl`:

```bash
curl -X POST http://localhost:8020/api/avatar/task \
  -F model=wav2lip \
  -F avatar_id=turin12 \
  -F video_file=@/ruta/al/video.mp4 \
  -F img_size=256
```

- `model`: `wav2lip` o `musetalk`.
- `avatar_id`: nombre de la carpeta que se creará en `data/avatars/<avatar_id>/`.
- `video_file`: vídeo fuente (cámara fija, boca cerrada, buena luz).
- Otros: `img_size` (256), `pads`, `bbox_shift`, `extra_margin`,
  `parsing_mode`, `version`, `notifyurl`… (ver `docs/avatar_api.md`).

La tarea es **asíncrona**. Consulta su estado con:

```bash
curl http://localhost:8020/api/avatar/task/<task_id>
curl http://localhost:8020/api/avatar/tasks
```

Cuando termine, en `data/avatars/<avatar_id>/` deben existir `coords.pkl`,
`full_imgs/` y `face_imgs/`. Después arranca LiveTalking con ese avatar
(`--avatar_id <avatar_id>`, o `LIVETALKING_AVATAR` en el `.env` de ctic-jAnItor).

> Si falta `coords.pkl`, la generación no terminó (mira el estado de la tarea y el
> log de LiveTalking).

Documentación completa: [`docs/avatar_api.md`](docs/avatar_api.md).

