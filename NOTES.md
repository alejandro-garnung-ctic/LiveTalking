# POC: LiveTalking + MuseTalk/wav2lip para avatar fotorrealista de portería (PorterIA)

Contexto: alternativa a TalkingHead (three.js + GLB + blendshapes ARKit/Oculus) para
un avatar de recepción más fotorrealista. Investigación completa en la conversación
de Claude Code del 2026-10-17 (sesión en `stock-market-exploration`).

## Estado del entorno (preparado sin usar GPU)

- Repo: `/opt/livetalking` (clon de
  https://github.com/lipku/LiveTalking, Apache-2.0; fuera de cualquier repo git del
  usuario a propósito, para no mezclar pesos de modelo de varios cientos de MB con
  ctic-jAnItor). Vive dentro de la macro carpeta de exploración
  `/opt/avatar-fotorealistic-exploration/` (ver su `README.md` y `alternatives.md`).
- Venv: `.venv` (Python 3.12.14 vía `uv`), con:
  - `torch==2.9.1+cu128`, `torchvision==0.24.1`, `torchaudio==2.9.1` (CUDA 12.8,
    compatible con el driver 13.2 de la RTX PRO 2000 Blackwell local).
  - Resto de `requirements.txt` instalado (opencv, aiortc/WebRTC, edge-tts,
    transformers, librosa, etc).
- Modelo: `models/wav2lip.pth` (wav2lip256, 205MB, descargado del Google Drive oficial
  del proyecto).
- Avatar de demo: `data/avatars/wav2lip256_avatar1/` (vídeo de una persona real ya
  procesado por LiveTalking, 337MB).
- TTS: `edge-tts` (Microsoft, gratuito), voz configurada en `config.yaml` →
  `REF_FILE: es-ES-AlvaroNeural`. Probado end-to-end sin GPU (genera audio correcto).
- No hace falta ninguna API key de pago para este POC base (el modo LLM/chat de
  LiveTalking usa DASHSCOPE_API_KEY, pero no es necesario para el modo "echo" que
  simplemente lee el texto en voz alta con lipsync).

## Por qué no se ha ejecutado inferencia todavía

La GPU local (RTX PRO 2000, 8GB) tiene casi toda la VRAM ocupada por un entrenamiento
activo del proyecto `swing-success-forecast` (`train.py --augment`, PID cambia porque
se reinicia solo entre rondas). Solo quedan ~400-450MB libres, insuficiente para
wav2lip256. No se ha tocado ese proceso.

## Cómo lanzar el POC en cuanto haya VRAM libre (objetivo: >=2-3GB libres)

```bash
cd /opt/livetalking
.venv/bin/python app.py --transport webrtc --model wav2lip --avatar_id wav2lip256_avatar1
```

Luego abrir `http://localhost:8010/index.html`, pulsar "iniciar conexión" y escribir
texto en español en el cuadro — debería reproducirse el avatar de demo hablando con
lipsync generado por wav2lip + la voz es-ES-AlvaroNeural.

Puertos: TCP 8010 (ya libre en esta máquina, comprobar antes de lanzar).

## Siguientes pasos si el resultado convence

1. Generar un avatar propio: grabar un vídeo corto (10-20s, cámara fija, buena luz,
   persona con indumentaria "seria" de cara al público) y subirlo vía
   `POST /api/avatar/task` (ver `docs/avatar_api.md`) con `model=wav2lip` o
   `model=musetalk`.
2. Si la calidad de wav2lip se queda corta, probar MuseTalk (mejor calidad, más VRAM:
   recomendado RTX 3080Ti+, aunque en la práctica MuseTalk realtime suele caber en
   6-8GB — pendiente de confirmar en esta GPU en concreto una vez haya VRAM libre).
3. Decidir licencia de despliegue: MuseTalk es MIT (uso comercial OK). Wav2Lip
   (el modelo, no LiveTalking) está entrenado sobre LRS2 y su uso comercial está
   restringido — válido para este POC de evaluación, pero habría que pasar a
   MuseTalk (o negociar licencia) antes de un despliegue real en portería.
4. Integración con PorterIA: sustituiría por completo el iframe de
   `services/avatar-3d` (three.js/TalkingHead) por un `<video>`/WebRTC consumiendo
   el stream de LiveTalking; el pipeline de texto→voz→avatar que ya tiene
   `janitor-logic` se reutilizaría casi igual, cambiando el backend de "avatar-3d"
   por una llamada a la API de LiveTalking (`/human`).

## Alternativa descartada por ahora: 3D Gaussian Splatting en three.js (LHM/LAM + splattie)

Mantiene el stack three.js actual pero: (a) LAM/LHM usan FLAME/SMPL-X, cuyas
licencias de uso comercial son ambiguas/no resueltas para el pipeline completo
(ver https://github.com/aigc3d/LAM/issues/111, sin respuesta oficial), y (b) no
tienen control de visemas en tiempo real listo de fábrica (animan por secuencias de
movimiento, no por fonema). Candidato a revisar más adelante si la licencia se
aclara: https://github.com/myned-ai/gsplat-flame-avatar-renderer (3DGS+FLAME con
soporte ARKit blendshapes).
