-- SIGRADO migracion flujo v4: alinea respuestas con FLUJO DEL SISTEMA
-- Cada respuesta guarda: responsable, fase, ronda, fecha, acta, comentarios y version evaluada
USE sigrado;
SET NAMES utf8mb4;

-- 1. Ronda (nro de respuesta dentro de la misma fase) y version evaluada del documento
-- MySQL 8.0: sin IF NOT EXISTS. Verificar antes con INFORMATION_SCHEMA si se re-ejecuta.
ALTER TABLE respuestas
  ADD COLUMN ronda INT NULL AFTER fase,
  ADD COLUMN version_evaluada INT NULL AFTER ronda,
  ADD COLUMN propuesta_url VARCHAR(500) NULL AFTER rejilla_fdc129_url;

-- 2. Backfill: ronda = correlativo por (proyecto_id, fase) ordenado por id;
--    version_evaluada = ultima version del documento principal de la fase al momento de la respuesta
--    F1: SoportePago, F2/F3: Propuesta_FDC124, F4/F5: Informe_FDC125, F6: NULL
UPDATE respuestas r
LEFT JOIN (
  SELECT id, ROW_NUMBER() OVER (PARTITION BY proyecto_id, fase ORDER BY id) AS rn
  FROM respuestas
) x ON x.id = r.id
SET r.ronda = x.rn
WHERE r.ronda IS NULL;

UPDATE respuestas r
LEFT JOIN (
  SELECT proyecto_id, tipo, MAX(version) AS mv FROM documentos GROUP BY proyecto_id, tipo
) d ON d.proyecto_id = r.proyecto_id
  AND ((r.fase IN (2,3) AND d.tipo = 'Propuesta_FDC124')
    OR (r.fase IN (4,5) AND d.tipo = 'Informe_FDC125')
    OR (r.fase = 1 AND d.tipo = 'SoportePago'))
SET r.version_evaluada = d.mv
WHERE r.version_evaluada IS NULL AND d.mv IS NOT NULL;

-- 3. Documentos: asegurar fase + observaciones (MariaDB acepta IF NOT EXISTS; en MySQL 8.0 verificar antes).
-- ALTER TABLE documentos
--   ADD COLUMN fase TINYINT NULL AFTER proyecto_id,
--   ADD COLUMN observaciones TEXT NULL AFTER nombre_archivo;
