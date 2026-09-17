# Tells y reemplazos

Referencia de consulta. Los ejemplos "antes" son texto real de un Capítulo 1 generado sin esta skill.

## 1. Hedging modal

El tell más frecuente y el más caro. Un verbo modal sobre el objeto de estudio siempre significa "no lo medí".

| Antes | Después |
|---|---|
| "puede clasificarse como una estructura funcional" | "es una estructura funcional: [dato] `[FUENTE?]`" |
| "los elementos pueden describirse de la siguiente manera" | "los elementos son: [lista con evidencia]" |
| "los servicios tercerizados pueden comprender" | "la empresa terceriza [n] servicios: [lista] `[FUENTE?]`" |
| "los puestos pueden agruparse en tres niveles" | "los puestos se agrupan en tres niveles (MOF interno, 2025)" |

El modal es legítimo solo para proyecciones y recomendaciones: "la propuesta podría reducir el tiempo de despacho en 18%".

## 2. Párrafo bookend

Cierre que resume lo recién dicho sin agregar nada. Se borra completo.

> **Antes:** [tras listar tres actividades numeradas] "En términos generales, RESEVICA S.A.C. desarrolla principalmente actividades comerciales y logísticas, orientadas a la venta mayorista y distribución de alimentos y bebidas, complementadas con servicios de transporte de carga por carretera."

> **Después:** *(borrado — las tres actividades ya estaban listadas arriba)*

Aperturas que casi siempre encabezan un bookend: "En términos generales", "En resumen", "Como se puede apreciar", "De esta manera", "consolidando así".

## 3. Repetición del sujeto

Un humano define la sigla una vez. La IA la repite en cada sección porque genera cada bloque aislado.

> **Antes:** "Representaciones y Servicios Virgen del Carmen S.A.C. (RESEVICA S.A.C.)" — repetido 7 veces en 2.122 palabras, más 10 usos de la sigla sola.

> **Regla:** nombre completo una vez, en la primera mención de la sección de datos generales. Después, la sigla. Después de eso, "la empresa".

## 4. Lista genérica

Si la lista sería igual de verdadera para cualquier competidor, no es un hallazgo — es relleno.

> **Antes:** siete servicios tercerizados "que pueden ser tercerizados": contabilidad, mantenimiento de vehículos, seguridad, limpieza, soporte informático, transporte complementario, asesoría legal.

> **Después:** los que la empresa **efectivamente** terceriza, con contrato o proveedor. Si no lo sabés: `[FUENTE?] — confirmar en entrevista con Gerencia Administrativa`.

## 5. Tripleta decorativa

Ritmo de tres por defecto: "comerciales y logísticas", "adquiridos, almacenados, comercializados y distribuidos". Suena completo, no informa.

Dejá los elementos que hacen trabajo. Si los tres son sinónimos, uno alcanza.

## 6. Fuente que se confiesa vacía

> "De acuerdo con los registros empresariales consultados…"
> "La información pública disponible no presenta un organigrama oficial. Sin embargo, considerando sus actividades…"

Eso es el texto avisando que está infiriendo. En una tesis, se resuelve de una de dos formas: conseguís el dato primario, o declarás la limitación explícitamente en la metodología. Nunca se disimula con "sin embargo, considerando".

## 7. Marcas de generación

`cite turn0search7`, `【4:0†source】`, corchetes vacíos, comillas tipográficas mezcladas. Grep antes de entregar:

```bash
grep -nE "cite turn|【|\[\d+\]|TODO|FUENTE\?" capitulo*.md
```

## 8. Frases de arranque huecas

Se borran sin reemplazo — la oración funciona igual sin ellas.

"Cabe destacar que" · "Es importante mencionar que" · "En este sentido" · "Por otro lado" (cuando no hay contraste real) · "A su vez" · "Asimismo" (encadenado tres veces seguidas)

---

# APA 7 — formatos de uso frecuente

## Cita en texto

- Paráfrasis: `(Chase & Jacobs, 2018)`
- Con autor en la oración: `Chase y Jacobs (2018) sostienen que…`
- Cita textual (agregá página): `(Chase & Jacobs, 2018, p. 214)`
- Tres o más autores, desde la primera vez: `(Krajewski et al., 2019)`
- Institución: primera vez `(Instituto Nacional de Estadística e Informática [INEI], 2024)`, después `(INEI, 2024)`

## Referencias

**Libro**
> Chase, R. B., & Jacobs, F. R. (2018). *Administración de operaciones: producción y cadena de suministros* (15.ª ed.). McGraw-Hill.

**Artículo con DOI**
> Apellido, A. A. (2023). Título del artículo. *Nombre de la Revista*, *12*(3), 45–67. https://doi.org/10.xxxx/xxxxx

**Tesis en repositorio**
> Apellido, A. A. (2024). *Título de la tesis* [Tesis de pregrado, Universidad Continental]. Repositorio Institucional Continental. https://repositorio.continental.edu.pe/...

**Norma técnica**
> Instituto Nacional de Calidad. (2021). *NTP 900.058:2021. Gestión de residuos*. INACAL.

**Documento interno** (no va en referencias; se cita en nota al pie o se anexa)
> Nota. Elaboración propia a partir del Manual de Organización y Funciones de la empresa (2025). Ver Anexo 3.

## Fuentes primarias del estudio

No son referencias bibliográficas. Se declaran en metodología y se anexan:

- Entrevista: `(Entrevista a Jefe de Operaciones, 12 de marzo de 2026)` → transcripción en anexos
- Observación: `(Observación directa, ruta Cusco–San Sebastián, 12–16 de marzo de 2026)`
- Registro interno: `(Registro de despachos, enero–marzo 2026)` → tabla en anexos

## Tablas y figuras

Numeración corrida por capítulo. Título arriba, fuente abajo.

```markdown
**Tabla 3**
*Tiempos de despacho por ruta, marzo 2026*

| Ruta | Pedidos | Tiempo promedio (min) |
|---|---|---|
| San Sebastián | 42 | 87 |
| Larapa | 31 | 112 |

*Nota.* Elaboración propia a partir del registro de despachos de la empresa.
```
