# TelleStory Nativo — prototipo de estabilidad 0.1

**Proyecto para abrir en Xcode (Mac), no en HostGator.**

## Objetivo
Eliminar el congelamiento que se observó en el navegador del iPhone.
La cámara nativa del teléfono sí grabó ~90 segundos completos; la web dejaba de
registrar imagen a los ~16 segundos. Esta versión usa `AVCaptureMovieFileOutput`
directamente y no depende de WebKit, canvas, MediaRecorder ni conversión web.

## Funciones incluidas
- Logo oficial proporcionado por el propietario de TelleStory.
- Teleprompter de texto, velocidad y tamaño de fuente ajustables.
- Cámara frontal/trasera y grabación nativa de video con voz.
- Grabación 9:16 con orientación vertical y salida `.mov` compatible con Fotos.
- Reproducción y botón **Guardar directamente en Fotos**.
- Compartir el archivo original desde iOS.
- Texto del teleprompter **no aparece en el archivo de video**.

## No incluidas todavía
- Música de fondo, filtros, edición, subtítulos automáticos o exportación MP4.
  Primero debemos confirmar estabilidad de la grabación original durante 90 s,
  luego 5 minutos. No se instaló ni probó todavía en un iPhone real.

## Instalar en un iPhone
1. En un **Mac con Xcode** actualizado, descomprime el ZIP.
2. Abre **TelleStory.xcodeproj**.
3. En Xcode, selecciona el proyecto TelleStory → Signing & Capabilities.
4. Elige tu equipo **Team** (Apple ID en Xcode → Settings → Accounts).
5. Si el Bundle Identifier está ocupado, cámbialo por uno exclusivo tuyo.
6. Conecta el iPhone al Mac o habilita conexión inalámbrica en Xcode; selecciónalo.
7. Pulsa el botón ▶ Run. Autoriza cámara, micrófono y guardado en Fotos.
8. Graba 90 segundos sin música; revisa el inicio, medio y final en Fotos.

## Notas importantes
- **No subas este ZIP a public_html/studio**: es código nativo, no una web.
- Compilar e instalar requiere macOS con Xcode y firma Apple (gratuita para pruebas
  personales según disponibilidad y limitaciones del programa de Apple).
- Las versiones web de TelleStory seguirán existiendo y no se modifican.
- Esta entrega se verificó a nivel de archivos y sintaxis Swift, pero **no se compiló
  con el SDK de iOS**, porque este entorno no dispone de Xcode ni macOS.
- El video sale como `.mov` nativo. iOS puede guardarlo en Fotos; no hay conversión
  adicional durante la grabación, para minimizar problemas.

## Siguiente prueba
Un video de 90 segundos debe mostrar movimiento hasta el último segundo y conservar
la voz. Cuando eso pase, avanzaremos a audio musical y ediciones con seguridad.
