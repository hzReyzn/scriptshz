# Halloween: video y nueva identidad visual

## Estado actual: mantenimiento

Por petición del propietario, `HzReyzn Hub.lua` tiene `HZ_MAINTENANCE = true`. Al ejecutarse, retira una instancia anterior del hub o de su introducción y muestra únicamente el aviso de mantenimiento. Cada ejecución comienza en inglés: «SERVER MAINTENANCE», «We'll be back soon.» y «The server is currently under maintenance. Thank you for your patience.». El selector permite elegir English, Español, Português o Русский y actualiza de inmediato el estado, título, mensaje, etiqueta de idioma y botón de cierre. Los nombres de los idiomas conservan su forma nativa para poder identificarlos; la selección no se guarda entre ejecuciones.

El aviso usa una tarjeta oscura, monograma HZ, borde con degradado ámbar, brillo interior, halo tenue y entrada/salida suaves. Las traducciones se incluyen en el script; no requieren servicios de traducción ni descargas de imágenes. Los controles nativos se desvanecen juntos sin crear una textura `CanvasGroup`. En pantallas estrechas, el selector cambia de cuatro columnas a dos filas y la tarjeta se ajusta a la altura disponible. Al cerrar o reemplazar el aviso se cancelan sus animaciones y conexiones.

El script termina antes de descargar recursos o iniciar módulos. Cerrar el aviso no abre el hub. La interfaz y la introducción quedan conservadas en el código para reabrirlas cuando el propietario lo indique; no hay reapertura programada.

Cuatro pruebas de mantenimiento verifican la ausencia de descargas y de inicio del hub, la traducción de todos los textos, la selección única y el inglés predeterminado, la adaptación a pantallas verticales/horizontales, el cierre, la cancelación de una introducción previa y la reejecución sin duplicados. Las diez pruebas anteriores ejercitan por separado el código conservado con el indicador desactivado solamente en el arnés. Son comprobaciones de comportamiento y geometría en un entorno simulado; la apariencia final se comprueba en Roblox.

## Cambios conservados para la reapertura

Esta actualización sustituye el loader anterior por el video proporcionado por el usuario. No modifica las funciones de vuelo, daño por caída, movimiento ni los scripts externos; su revisión queda para el siguiente encargo.

## Recursos

| Archivo recibido | Uso |
| --- | --- |
| `1000190453.mp4` | Introducción completa de aproximadamente 18,35 segundos, con su audio original. |
| `1000190446.jpg` | Fondo del tema Halloween dentro de la ventana del hub. |
| `1000190442.mp4` | Referencia para la ubicación del fondo; no se reproduce ni se publica. |
| `1000190441.png` | Logo HZ del encabezado, botón minimizado, vista previa de tema y bienvenida. El archivo recibido contiene JPEG; se conserva sin modificar con extensión `.jpg`. |

Las dos imágenes se conservan byte por byte. Para resolver la pantalla negra observada con la reproducción nativa, la introducción usa los fotogramas del video original a 24 fps y 512×288, conservando su encuadre, orden y duración. Son 441 fotogramas distribuidos en 74 hojas JPEG de 1024×864. Su pista de audio original se convierte a OGG Vorbis estéreo; no se añade música ni se repite el audio.

Los recursos de esta versión están en `assets/halloween/sequence-v3/`: siete paquetes de fotogramas y `soundtrack.ogg`, aproximadamente 11,7 MB en total. Cada paquete comienza con `HZF1`, seguido de un contador de imágenes de 32 bits y pares longitud/JPEG; los enteros usan little endian. El cliente verifica firmas y tamaños, extrae las hojas y guarda las imágenes y el audio con nombres versionados. Los videos WEBM/MP4 anteriores se conservan en el repositorio, pero esta introducción no los solicita.

## Comportamiento

- La entrada usa tres `ImageLabel` rotativos con `ImageRectOffset` e `ImageRectSize`. No crea un `VideoFrame` ni depende de su decodificador. Esta alternativa reduce la resolución respecto al archivo original para permitir su reproducción mediante imágenes locales.
- La imagen aparece progresivamente durante 0,7 s y se desvanece durante los últimos 0,95 s. La opacidad del fondo y el volumen del audio original acompañan los desvanecimientos.
- No se dibuja otra barra o porcentaje sobre el video y no es necesario tocar para continuar.
- El video conserva su relación 16:9 completa, incluso en pantallas móviles.
- Reiniciar o destruir el hub cancela la entrada previa y libera las imágenes, el audio y las conexiones.
- Tres trabajadores descargan los paquetes. La introducción espera inicialmente los primeros seis segundos de imágenes, con la pantalla transparente durante la descarga. Si necesita más datos durante la reproducción, conserva el último fotograma y pausa el audio; ambos continúan juntos cuando los datos están disponibles.
- Las descargas, la preparación y las pausas tienen límites. Un fallo libera la pantalla y permite abrir el hub con un aviso en la consola.
- Las imágenes y el sonido usan `writefile` y `getcustomasset`/`getsynasset`. Este modo utiliza el mismo mecanismo de recursos locales que el logo, cuya visualización ya confirmó el usuario. La reproducción y el audio en su cliente concreto deben comprobarse allí.
- El fondo solamente aparece con Halloween. Los otros temas permanecen seleccionables.
- Se conserva la corrección del logo: se hace visible al asignar su recurso, sin bloquear la carga esperando a `IsLoaded`.
- La descarga del código del loader incluye la revisión `frames-3` para evitar reutilizar la copia anterior en caché.
- El tema añade brasas, luz interior, reflejos y desplazamiento ambiental suave; `Animated accents` permite detenerlos. Las animaciones ambientales paran cuando la ventana está oculta.
- Halloween ya no repinta todos los controles y atributos veinte veces por segundo: actualiza únicamente las propiedades de los elementos que se animan.
- El selector de páginas, la apertura, minimizar/restaurar y el cierre tienen transiciones suaves. Los destellos conservan el color del tema seleccionado.

## Verificación

Diez escenarios de `tests/behavior.luau` cubren los controles anteriores como regresión, reproducción y audio, cancelación, reejecución, ausencia de soporte multimedia, conservación del fotograma y pausa/reanudación del audio durante una espera, imágenes del hub, pausa del movimiento e indicadores `IsLoaded` que se retrasan para recursos locales. El arnés no valida el renderizado ni el audio real en Roblox. También se compilaron los archivos modificados con Luau, se compararon los 74 JPEG extraídos de los paquetes con sus originales y se verificaron los metadatos de la pista de audio.

La prueba final de reproducción y diseño en el cliente Roblox del usuario sigue pendiente.
