---
name: redaccion-tesis
description: Use when writing, drafting or revising any section of a Spanish-language thesis, tesis, trabajo de investigación, informe de mejora de procesos or capítulo académico — including when the draft reads as AI-generated, hedges with "puede/pueden", cites no sources, or contains no measured figures.
---

# Redacción de tesis

## Overview

En una tesis, la prosa no sustituye al dato. Cuando falta evidencia, el texto se marca — no se rellena con lenguaje.

Un capítulo que suena a IA casi nunca tiene un problema de vocabulario. Tiene un problema de fuente: describe una empresa que el autor no midió. La prosa pulida es el síntoma; el hueco de evidencia es la causa.

## El contrato del párrafo

Todo párrafo afirmativo sobre el objeto de estudio tiene tres partes, en este orden:

1. **Afirmación** — qué es verdad. Presente de indicativo, sin verbo modal.
2. **Magnitud o detalle verificable** — una cifra, fecha, cantidad, código o nombre de documento.
3. **Fuente** — de dónde salió: documento interno, entrevista, observación directa, o cita APA.

Si falta (2) o (3), escribí la afirmación y cerrá con `[FUENTE?]`. No agregues prosa para compensar.

```
✗ La estructura organizativa puede clasificarse como funcional y vertical.

✓ La estructura organizativa es funcional y vertical: cuatro áreas reportan
  directamente a Gerencia General. [FUENTE?]

✓ La estructura organizativa es funcional y vertical: cuatro áreas y 23
  trabajadores reportan a Gerencia General (Organigrama interno, octubre 2025).
```

Las tres dicen lo mismo. Solo la tercera es una tesis.

## Regla de magnitud

Toda sección que describa una operación — procesos, diagnóstico, indicadores, resultados — contiene **al menos una magnitud medida**: tiempo, distancia, cantidad, costo, frecuencia o porcentaje.

Sección operativa sin ninguna magnitud → abrila con `[SIN DATO OPERATIVO]` y listá qué habría que medir. No la redactes bonita.

## Prohibiciones

Estas no se negocian:

- **Nunca conviertas un hueco de evidencia en prosa.** Si no sabés el dato, `[FUENTE?]`. Escribir alrededor del hueco es el fallo que esta skill existe para impedir.
- **Nunca uses verbo modal para describir el objeto de estudio.** "puede clasificarse", "pueden comprender", "podría considerarse" → o lo afirmás con evidencia, o lo marcás.
- **Nunca cierres una sección resumiendo lo que acabás de decir.** Si el párrafo final no aporta dato nuevo, se borra entero.
- **Nunca dejes marcas de generación.** `cite turnXsearchY`, `【】`, `[1]` sin referencia, placeholders. Se revisan antes de entregar, siempre.

## Test de eliminación

Aplicalo a cada oración: **¿contiene información que no esté ya en la oración anterior?**

Si no, borrala. No la reescribas — borrala. Es la herramienta más rápida que tenés para limpiar un borrador.

## Racionalizaciones

| Excusa | Realidad |
|---|---|
| "Es solo el marco descriptivo, no necesita datos" | El Capítulo 1 es donde el jurado decide si conocés la empresa. Sin datos, no la conocés. |
| "Después le pongo las fuentes" | Si escribís primero y citás después, vas a citar lo que encuentre, no lo que afirmaste. Marcá el hueco ahora. |
| "Con información pública alcanza para empezar" | Alcanza para el RUC y poco más. Un organigrama inferido de SUNAT es una invención con formato de dato. |
| "El `[FUENTE?]` queda feo en el borrador" | El borrador no se entrega. Lo feo es que el jurado encuentre el hueco primero. |
| "Suena mejor con el párrafo de cierre" | Sonar mejor y decir más no son lo mismo. Aplicá el test de eliminación. |
| "Lo puliría, pero no tengo acceso a la empresa" | Entonces el problema no es de redacción y pulir no lo arregla. Los `[FUENTE?]` son tu lista de qué ir a buscar. |

## Red flags — pará y marcá el hueco

- Escribiste "puede", "pueden", "podría" sobre la empresa estudiada
- Una sección operativa sin una sola cifra
- "En términos generales…", "Cabe destacar…", "Es importante mencionar…"
- Un párrafo final que repite el anterior con otras palabras
- Repetiste el nombre completo de la empresa por tercera vez en la misma página
- Una lista que sería igual de verdadera para cualquier otra empresa del rubro

**Todas significan lo mismo: falta un dato. Marcalo, no lo redactes.**

## Referencia

Tells concretos con reemplazos, y formatos APA 7: ver `tells-y-reemplazos.md` en este directorio.
