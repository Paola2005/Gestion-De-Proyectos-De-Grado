-- SIGRADO migracion flujo v3: corrige tablas faltantes y estados segun FLUJO DEL SISTEMA
USE sigrado;
SET NAMES utf8mb4;

-- 1. Calendario interno (usado por comun/calendario.jsp). No existia en BD viva (solo calendario_eventos).
CREATE TABLE IF NOT EXISTS calendario_actividades (
  id INT AUTO_INCREMENT PRIMARY KEY,
  periodo_id INT NOT NULL,
  titulo VARCHAR(200) NOT NULL,
  descripcion TEXT,
  fecha_inicio DATE NOT NULL,
  fecha_fin DATE,
  tipo ENUM('Academico','Administrativo','Grado','Otro') NOT NULL,
  responsable INT NOT NULL,
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (periodo_id) REFERENCES periodos(id),
  FOREIGN KEY (responsable) REFERENCES usuarios(id),
  INDEX idx_periodo_fecha (periodo_id, fecha_inicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Asegurar estados validos segun flujo:
-- proyectos.estado solo: En curso, Rechazado, Cancelado, Finalizado
-- respuestas.estado solo: Aprobado, Correcciones, Rechazado (Correcciones = Aplazado)
-- sustentaciones.resultado: Aprobado, Aplazado, Rechazado
-- No se altera ENUM aqui para no romper datos existentes; verificar con:
-- SELECT DISTINCT estado FROM proyectos;
-- SELECT DISTINCT estado FROM respuestas;
-- SELECT DISTINCT resultado FROM sustentaciones;

-- 3. Documentos ya tiene fase + observaciones en BD viva (correcto). Si falta en otro entorno:
ALTER TABLE documentos
  ADD COLUMN IF NOT EXISTS fase TINYINT NULL AFTER proyecto_id,
  ADD COLUMN IF NOT EXISTS observaciones TEXT NULL AFTER nombre_archivo;
