# Halloween: video y nueva identidad visual

Esta actualización sustituye el loader anterior por el video proporcionado por el usuario. No modifica las funciones de vuelo, daño por caída, movimiento ni los scripts externos; su revisión queda para el siguiente encargo.

## Recursos

| Archivo recibido | Uso |
| --- | --- |
| `1000190453.mp4` | Introducción completa de aproximadamente 18,35 segundos, con su audio original. |
| `1000190446.jpg` | Fondo del tema Halloween dentro de la ventana del hub. |
| `1000190442.mp4` | Referencia para la ubicación del fondo; no se reproduce ni se publica. |
| `1000190441.png` | Logo HZ del encabezado, botón minimizado, vista previa de tema y bienvenida. El archivo recibido contiene JPEG; se conserva sin modificar con extensión `.jpg`. |

Las dos imágenes se conservan byte por byte. El video se convierte a 1280×720, 30 fps, manteniendo encuadre, duración y pista de audio: WEBM VP8/Vorbis como primera opción y MP4 H.264/AAC como alternativa. No se añade música ni se repite el audio. Los recursos están en `assets/halloween/` y se guardan en la caché local del cliente con nombres versionados.

## Comportamiento

- La entrada usa un `VideoFrame` dentro de un `Frame` normal. Una cortina negra independiente produce la aparición de 0,7 s y el desvanecimiento durante los últimos 0,95 s, sincronizado con el tiempo de reproducción. Al terminar, la cortina se desvanece hacia el juego en 0,35 s. El video no depende del renderizado de `CanvasGroup`.
- El audio del video está habilitado por defecto. Su volumen acompaña ambos desvanecimientos.
- No se dibuja otra barra o porcentaje sobre el video y no es necesario tocar para continuar.
- El video conserva su relación 16:9 completa, incluso en pantallas móviles.
- Reiniciar o destruir el hub cancela la entrada previa y libera el video y su audio.
- Se prueba MP4 si WEBM no puede empezar. Descargas y espera del decodificador tienen límites; una reproducción detenida no bloquea indefinidamente el hub.
- Las imágenes usan `writefile` y `getcustomasset`/`getsynasset`, igual que el loader anterior. La reproducción local depende de las capacidades del cliente. Si ninguna fuente funciona, se abre el hub con un aviso en la consola.
- El fondo solamente aparece con Halloween. Los otros temas permanecen seleccionables.
- El logo se hace visible al asignar su recurso, sin esperar a `IsLoaded`; así puede iniciar su carga. Se solicita precarga de las imágenes. El video se inicia directamente y confirma que avanza `TimePosition`, en lugar de bloquearse por el indicador `IsLoaded` de un recurso local.
- La descarga del código del loader incluye la revisión `visibility-2` para evitar reutilizar la copia anterior en caché.
- El tema añade brasas, luz interior, reflejos y desplazamiento ambiental suave; `Animated accents` permite detenerlos. Las animaciones ambientales paran cuando la ventana está oculta.
- Halloween ya no repinta todos los controles y atributos veinte veces por segundo: actualiza únicamente las propiedades de los elementos que se animan.
- El selector de páginas, la apertura, minimizar/restaurar y el cierre tienen transiciones suaves. Los destellos conservan el color del tema seleccionado.

## Verificación

Se compilaron los archivos modificados con Luau. Diez escenarios de `tests/behavior.luau` cubren los controles anteriores como regresión, la reproducción y los desvanecimientos, cancelación, reejecución, alternativa MP4, ausencia de soporte multimedia, reproducción detenida, imágenes, pausa del movimiento e indicadores `IsLoaded` que no se actualizan para recursos locales. El arnés ahora simula carga diferida de imágenes invisibles y un cliente que no reproduce videos dentro de `CanvasGroup`; no valida decodificación ni apariencia real en Roblox. Se verificaron además los metadatos de ambos videos y las firmas/tamaños de todos los recursos.

La prueba final de reproducción y diseño en el cliente Roblox del usuario sigue pendiente.
