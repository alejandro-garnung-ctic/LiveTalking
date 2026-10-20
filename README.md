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

