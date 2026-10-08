-- ============================================================
-- SIGRADO - Sistema de Gestión de Trabajos de Grado
-- Base de datos MySQL - Script maestro DDL + Datos semilla
-- Versión corregida: sin tabla grupos, sin grupo_id, estados corregidos
-- ============================================================

DROP DATABASE IF EXISTS sigrado;
CREATE DATABASE sigrado CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE sigrado;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ============================================================
-- 1. USUARIOS, ROLES Y PERMISOS
-- ============================================================
CREATE TABLE usuarios (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  documento       VARCHAR(20)  NOT NULL UNIQUE,
  nombres         VARCHAR(80)  NOT NULL,
  apellidos       VARCHAR(80)  NOT NULL,
  email           VARCHAR(120) NOT NULL UNIQUE,
  password_hash   CHAR(64)     NOT NULL,
  telefono        VARCHAR(20),
  programa        VARCHAR(80)  DEFAULT 'Ingeniería de Sistemas',
  activo          TINYINT(1)   DEFAULT 1,
  fecha_registro  TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_email (email),
  INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
  id     TINYINT AUTO_INCREMENT PRIMARY KEY,
  nombre ENUM('administrador','comite','docente','estudiante') NOT NULL UNIQUE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE usuario_rol (
  usuario_id INT NOT NULL,
  rol_id     TINYINT NOT NULL,
  PRIMARY KEY (usuario_id, rol_id),
  FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
  FOREIGN KEY (rol_id)     REFERENCES roles(id)     ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 2. PERIODOS ACADÉMICOS Y CONFIGURACIÓN
-- ============================================================
CREATE TABLE periodos (
  id                          INT AUTO_INCREMENT PRIMARY KEY,
  codigo                      VARCHAR(10) NOT NULL UNIQUE,
  inicio_propuestas_banco     DATE NOT NULL,
  fin_propuestas_banco        DATE NOT NULL,
  inicio_nuevos_proyectos     DATE NOT NULL,
  fin_aprobacion_propuesta    DATE NOT NULL,
  activo                      TINYINT(1) DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 3. PROPUESTAS DE BANCO (subidas por DOCENTES, aprobadas por COMITÉ)
-- ============================================================
CREATE TABLE propuestas_banco (
  id                        INT AUTO_INCREMENT PRIMARY KEY,
  codigo                    VARCHAR(15) NOT NULL UNIQUE,
  docente_id                INT NOT NULL,
  titulo                    VARCHAR(200) NOT NULL,
  tipo_modalidad            ENUM('Desarrollo tecnologico','Emprendimiento','Investigacion','Otro') NOT NULL,
  objetivo_general          TEXT NOT NULL,
  linea_investigacion       VARCHAR(120) NOT NULL,
  tipo_nivel                ENUM('Tecnologico','Profesional') NOT NULL,
  periodo_id                INT NOT NULL,
  estado                    ENUM('Pendiente','Aprobada','Rechazada') DEFAULT 'Pendiente',
  disponible                TINYINT(1) DEFAULT 1,
  fecha_propuesta           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_revision            TIMESTAMP NULL,
  comite_revisor_id         INT NULL,
  observacion_comite        TEXT NULL,
  FOREIGN KEY (docente_id)       REFERENCES usuarios(id),
  FOREIGN KEY (periodo_id)       REFERENCES periodos(id),
  FOREIGN KEY (comite_revisor_id) REFERENCES usuarios(id),
  INDEX idx_estado (estado),
  INDEX idx_disponible (disponible)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 4. PROYECTOS DE GRADO (núcleo de la máquina de estados)
-- SIN grupo_id, usando proyecto_integrantes
-- ============================================================
CREATE TABLE proyectos (
  id                     INT AUTO_INCREMENT PRIMARY KEY,
  codigo                 VARCHAR(15) NOT NULL UNIQUE,
  banco_id               INT NULL,
  titulo                 VARCHAR(200) NOT NULL,
  objetivo_general       TEXT,
  descripcion            TEXT,
  tipo_idea              ENUM('Propia','Banco') NOT NULL,
  tipo_modalidad         ENUM('Desarrollo tecnologico','Emprendimiento','Investigacion','Otro'),
  tipo_nivel             ENUM('Tecnologico','Profesional'),
  periodo_id             INT NOT NULL,
  codigo_modalidad       VARCHAR(20) NULL,
  fase                   TINYINT NOT NULL DEFAULT 1,
  responsable            ENUM('comite','estudiante','director','evaluador') NOT NULL DEFAULT 'comite',
  estado                 ENUM('En curso','Rechazado','Cancelado','Finalizado') NOT NULL DEFAULT 'En curso',
  director_id            INT NULL,
  evaluador_id           INT NULL,
  codirector_id          INT NULL,
  fecha_creacion         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  fecha_actualizacion    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (banco_id)     REFERENCES propuestas_banco(id),
  FOREIGN KEY (periodo_id)   REFERENCES periodos(id),
  FOREIGN KEY (director_id)  REFERENCES usuarios(id),
  FOREIGN KEY (evaluador_id) REFERENCES usuarios(id),
  FOREIGN KEY (codirector_id) REFERENCES usuarios(id),
  INDEX idx_fase_resp (fase, responsable),
  INDEX idx_director (director_id),
  INDEX idx_evaluador (evaluador_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE proyecto_integrantes (
  proyecto_id  INT NOT NULL,
  usuario_id   INT NOT NULL,
  es_responsable TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (proyecto_id, usuario_id),
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id)  REFERENCES usuarios(id)  ON DELETE CASCADE,
  INDEX idx_responsable (es_responsable)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 5. DOCUMENTOS (enlaces a Drive/OneDrive, versionados)
-- ============================================================
CREATE TABLE documentos (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  proyecto_id       INT NOT NULL,
  tipo              ENUM('SoportePago','Propuesta_FDC124','Turnitin_FDC124',
                          'Informe_FDC125','Turnitin_FDC125','Rejilla_FDC129','Otro') NOT NULL,
  version           INT NOT NULL,
  url               VARCHAR(500) NOT NULL,
  nombre_archivo    VARCHAR(200),
  subido_por        INT NOT NULL,
  fecha_subida      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (subido_por)  REFERENCES usuarios(id),
  UNIQUE KEY uk_proy_tipo_ver (proyecto_id, tipo, version),
  INDEX idx_proy_tipo (proyecto_id, tipo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 6. RESPUESTAS / EVALUACIONES POR FASE
-- ============================================================
CREATE TABLE respuestas (
  id                  INT AUTO_INCREMENT PRIMARY KEY,
  proyecto_id         INT NOT NULL,
  fase                TINYINT NOT NULL,
  ronda               INT NULL COMMENT 'Nro de respuesta dentro de la misma fase (1,2,...). Correcciones incrementa ronda',
  version_evaluada    INT NULL COMMENT 'Version del documento evaluado (documentos.version)',
  usuario_id          INT NOT NULL,
  rol                 ENUM('comite','director','evaluador') NOT NULL,
  estado              ENUM('Aprobado','Correcciones','Rechazado') NOT NULL,
  acta_numero         VARCHAR(30) NULL,
  acta_fecha          DATE NULL,
  comentario          TEXT,
  codigo_modalidad    VARCHAR(20) NULL,
  director_id         INT NULL,
  evaluador_id        INT NULL,
  codirector_id       INT NULL,
  turnitin_url        VARCHAR(500) NULL,
  informe_fdc125_url  VARCHAR(500) NULL,
  rejilla_fdc129_url  VARCHAR(500) NULL,
  propuesta_url       VARCHAR(500) NULL COMMENT 'Propuesta firmada F-DC-124 (Fase 3)',
  fecha               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id)  REFERENCES usuarios(id),
  FOREIGN KEY (director_id)  REFERENCES usuarios(id),
  FOREIGN KEY (evaluador_id) REFERENCES usuarios(id),
  FOREIGN KEY (codirector_id) REFERENCES usuarios(id),
  INDEX idx_proy_fase (proyecto_id, fase)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 7. HISTORIAL / BITÁCORA
-- ============================================================
CREATE TABLE historial (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  proyecto_id       INT NOT NULL,
  usuario_id        INT NOT NULL,
  accion            VARCHAR(80) NOT NULL,
  fase              TINYINT NULL,
  acta_numero       VARCHAR(30) NULL,
  comentario        TEXT,
  fecha             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE,
  FOREIGN KEY (usuario_id)  REFERENCES usuarios(id),
  INDEX idx_proy_fecha (proyecto_id, fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 8. FORMATOS DE GRADO (gestionados por Administrador)
-- ============================================================
CREATE TABLE formatos (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  codigo          VARCHAR(30) NOT NULL UNIQUE,
  nombre          VARCHAR(255) NOT NULL,
  url             VARCHAR(500) NOT NULL,
  activo          TINYINT(1) DEFAULT 1,
  fecha_creacion  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 9. SUSTENTACIONES (Fase 6)
-- ============================================================
CREATE TABLE sustentaciones (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  proyecto_id       INT NOT NULL,
  fecha             DATE NOT NULL,
  hora              TIME NOT NULL,
  lugar_o_enlace    VARCHAR(255) NOT NULL,
  jurados           VARCHAR(255) NULL,
  resultado         ENUM('Aprobado','Aplazado','Rechazado') DEFAULT 'Aprobado',
  numero_acta       VARCHAR(50) NOT NULL,
  observaciones     TEXT NULL,
  fecha_registro    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id) ON DELETE CASCADE,
  INDEX idx_proy (proyecto_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 10. AUDITORÍA
-- ============================================================
CREATE TABLE auditoria (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  fecha           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  usuario_id      INT NULL,
  accion          VARCHAR(100) NOT NULL,
  entidad         VARCHAR(80) NULL,
  detalle         TEXT NULL,
  KEY (usuario_id),
  KEY (fecha)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 11. NOTIFICACIONES
-- ============================================================
CREATE TABLE notificaciones (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  usuario_id    INT NOT NULL,
  titulo        VARCHAR(150) NOT NULL,
  mensaje       TEXT NOT NULL,
  leido         TINYINT(1) DEFAULT 0,
  url_destino   VARCHAR(255) NULL,
  fecha         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  KEY (usuario_id),
  KEY (leido)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 12. CALENDARIO DE ACTIVIDADES INTERNO
-- ============================================================
CREATE TABLE calendario_actividades (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  periodo_id      INT NOT NULL,
  titulo          VARCHAR(200) NOT NULL,
  descripcion     TEXT,
  fecha_inicio    DATE NOT NULL,
  fecha_fin       DATE,
  tipo            ENUM('Academico','Administrativo','Grado','Otro') NOT NULL,
  responsable     INT NOT NULL,
  fecha_creacion  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (periodo_id) REFERENCES periodos(id),
  FOREIGN KEY (responsable) REFERENCES usuarios(id),
  INDEX idx_periodo_fecha (periodo_id, fecha_inicio)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- 13. REPORTES (opcional, para PDFs generados)
-- ============================================================
CREATE TABLE reportes (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  proyecto_id     INT NOT NULL,
  tipo            ENUM('Seguimiento','Acta','Constancia') NOT NULL,
  archivo_url     VARCHAR(500) NOT NULL,
  generado_por    INT NOT NULL,
  fecha           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (proyecto_id) REFERENCES proyectos(id),
  FOREIGN KEY (generado_por)  REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- DATOS SEMILLA
-- ============================================================

-- Roles (IDs: 1=administrador, 2=comite, 3=docente, 4=estudiante)
INSERT INTO roles (id, nombre) VALUES 
(1, 'administrador'),
(2, 'comite'),
(3, 'docente'),
(4, 'estudiante');

-- Periodo activo 2026-2
INSERT INTO periodos (codigo, inicio_propuestas_banco, fin_propuestas_banco,
                      inicio_nuevos_proyectos, fin_aprobacion_propuesta)
VALUES ('2026-2','2026-07-01','2026-08-15','2026-08-16','2026-10-31');

-- Usuarios (password = '123456' hasheado con SHA2)
INSERT INTO usuarios (documento,nombres,apellidos,email,password_hash,telefono,activo) VALUES
('1001','Ana Maria','Comité','comite@uts.edu.co',SHA2('123456',256),'3001111111',1),
('1002','Carlos','Administrador','admin@uts.edu.co',SHA2('123456',256),'3002222222',1),
('1003','David','Director','director@uts.edu.co',SHA2('123456',256),'3003333333',1),
('1004','Eva','Evaluadora','eval@uts.edu.co',SHA2('123456',256),'3004444444',1),
('1005','Felipe','Docente Mixto','docente@uts.edu.co',SHA2('123456',256),'3005555555',1),
('2001','Laura','Estudiante Uno','est1@uts.edu.co',SHA2('123456',256),'3101111111',1),
('2002','Mario','Estudiante Dos','est2@uts.edu.co',SHA2('123456',256),'3102222222',1),
('2003','Nina','Estudiante Tres','est3@uts.edu.co',SHA2('123456',256),'3103333333',1),
('2004','Oscar','Estudiante Cuatro','est4@uts.edu.co',SHA2('123456',256),'3104444444',1);

-- Asignación de roles
INSERT INTO usuario_rol (usuario_id,rol_id) VALUES
(1,2), -- Ana = comité
(2,1), -- Carlos = administrador
(3,3), (3,2), -- David = docente + comité
(4,3), -- Eva = docente
(5,3), -- Felipe = docente
(6,4), (7,4), (8,4), (9,4); -- estudiantes

-- Propuesta de banco aprobada (docente Felipe)
INSERT INTO propuestas_banco (codigo,docente_id,titulo,tipo_modalidad,objetivo_general,
  linea_investigacion,tipo_nivel,periodo_id,estado,disponible)
VALUES ('BAN-00001',5,'Sistema de gestión académica','Desarrollo tecnologico',
  'Automatizar procesos de matrícula y notas','Ingeniería de Software','Profesional',1,'Aprobada',1);

-- Segunda propuesta pendiente
INSERT INTO propuestas_banco (codigo,docente_id,titulo,tipo_modalidad,objetivo_general,
  linea_investigacion,tipo_nivel,periodo_id,estado,disponible)
VALUES ('BAN-00002',5,'App móvil para emprendimiento','Emprendimiento',
  'Plataforma de conexión inversores-emprendedores','Ingeniería de Software','Tecnologico',1,'Pendiente',1);

-- Proyecto en Fase 2 (Estudiante Laura selecciona BAN-00001)
INSERT INTO proyectos (codigo,banco_id,titulo,objetivo_general,descripcion,
  tipo_idea,tipo_modalidad,tipo_nivel,periodo_id,codigo_modalidad,fase,responsable,estado,
  director_id,evaluador_id)
VALUES ('GRA-00001',1,'Sistema de gestión académica',
  'Automatizar procesos de matrícula y notas','Aplicación web fullstack','Banco',
  'Desarrollo tecnologico','Profesional',1,'65-2026-001',2,'estudiante','En curso',
  3,4);
SET @pid = LAST_INSERT_ID();
INSERT INTO proyecto_integrantes (proyecto_id,usuario_id,es_responsable) VALUES (@pid,6,1);

-- Documentos Fase 1 (soportes de pago)
INSERT INTO documentos (proyecto_id,tipo,version,url,nombre_archivo,subido_por) VALUES
(@pid,'SoportePago',1,'https://drive.google.com/file/d/1abc/view','Comprobante_pago.pdf',6),
(@pid,'SoportePago',2,'https://drive.google.com/file/d/1def/view','Comprobante_pago_v2.pdf',6);

-- Proyecto en Fase 1 (estudiante Mario propone idea propia)
INSERT INTO proyectos (codigo,banco_id,titulo,objetivo_general,descripcion,
  tipo_idea,tipo_modalidad,tipo_nivel,periodo_id,fase,responsable,estado)
VALUES ('GRA-00002',NULL,'Plataforma IoT para agricultura','Monitoreo de cultivos','Sensores + web','Propia',
  'Investigacion','Tecnologico',1,1,'comite','En curso');
SET @pid2 = LAST_INSERT_ID();
INSERT INTO proyecto_integrantes (proyecto_id,usuario_id,es_responsable) VALUES (@pid2,7,1);

-- Proyecto en Fase 3 (Director aprobó, Evaluador debe revisar)
INSERT INTO proyectos (codigo,banco_id,titulo,objetivo_general,descripcion,
  tipo_idea,tipo_modalidad,tipo_nivel,periodo_id,codigo_modalidad,fase,responsable,estado,
  director_id,evaluador_id)
VALUES ('GRA-00003',NULL,'Sistema de citas médicas','Gestión de turnos','App móvil + backend','Propia',
  'Desarrollo tecnologico','Profesional',1,'125-2026-045',3,'evaluador','En curso',
  3,4);
SET @pid3 = LAST_INSERT_ID();
INSERT INTO proyecto_integrantes (proyecto_id,usuario_id,es_responsable) VALUES (@pid3,8,1);
INSERT INTO documentos (proyecto_id,tipo,version,url,nombre_archivo,subido_por) VALUES
(@pid3,'Propuesta_FDC124',1,'https://drive.google.com/file/d/1ghi/view','Propuesta_FDC124_v1.pdf',8),
(@pid3,'Turnitin_FDC124',1,'https://drive.google.com/file/d/1jkl/view','Turnitin_Propuesta.pdf',8);

-- Respuestas de Fase 1 y 2 para proyecto 3
INSERT INTO respuestas (proyecto_id,fase,usuario_id,rol,estado,acta_numero,acta_fecha,comentario,
  codigo_modalidad,director_id,evaluador_id)
VALUES (@pid3,1,1,'comite','Aprobado','ACTA-2026-001','2026-08-20','Propuesta aprobada, se asigna tribunal','125-2026-045',3,4),
(@pid3,2,3,'director','Aprobado','ACTA-2026-015','2026-09-10','Propuesta aprobada, pasa a evaluador',NULL,NULL,NULL,NULL);

-- Proyecto en Fase 4 (Evaluador aprobó, Estudiante envía informe)
INSERT INTO proyectos (codigo,banco_id,titulo,objetivo_general,descripcion,
  tipo_idea,tipo_modalidad,tipo_nivel,periodo_id,codigo_modalidad,fase,responsable,estado,
  director_id,evaluador_id)
VALUES ('GRA-00004',NULL,'E-commerce para pyme','Tienda online','React + Node','Propia',
  'Desarrollo tecnologico','Profesional',1,'65-2026-078',4,'estudiante','En curso',
  3,4);
SET @pid4 = LAST_INSERT_ID();
INSERT INTO proyecto_integrantes (proyecto_id,usuario_id,es_responsable) VALUES (@pid4,9,1);
INSERT INTO documentos (proyecto_id,tipo,version,url,nombre_archivo,subido_por) VALUES
(@pid4,'Propuesta_FDC124',1,'https://drive.google.com/file/d/1mno/view','Propuesta_FDC124_v1.pdf',9),
(@pid4,'Turnitin_FDC124',1,'https://drive.google.com/file/d/1pqr/view','Turnitin_Propuesta.pdf',9),
(@pid4,'Informe_FDC125',1,'https://drive.google.com/file/d/1stu/view','Informe_FDC125_v1.pdf',9);

-- Respuestas para proyecto 4 (fases 1,2,3 completadas)
INSERT INTO respuestas (proyecto_id,fase,usuario_id,rol,estado,acta_numero,acta_fecha,comentario,
  codigo_modalidad,director_id,evaluador_id) VALUES
(@pid4,1,1,'comite','Aprobado','ACTA-2026-002','2026-08-22','Aprobado','65-2026-078',3,4),
(@pid4,2,3,'director','Aprobado','ACTA-2026-016','2026-09-12','Propuesta OK',NULL,NULL,NULL),
(@pid4,3,4,'evaluador','Aprobado','ACTA-2026-030','2026-09-25','Propuesta aprobada',NULL,NULL,NULL,NULL);

-- Proyecto en Fase 5 Comité (Finalizado)
INSERT INTO proyectos (codigo,banco_id,titulo,objetivo_general,descripcion,
  tipo_idea,tipo_modalidad,tipo_nivel,periodo_id,codigo_modalidad,fase,responsable,estado,
  director_id,evaluador_id)
VALUES ('GRA-00005',NULL,'Sistema de inventario','Control de stock','Java Spring','Propia',
  'Desarrollo tecnologico','Profesional',1,'125-2026-099',6,'comite','Finalizado',
  3,4);
SET @pid5 = LAST_INSERT_ID();
INSERT INTO proyecto_integrantes (proyecto_id,usuario_id,es_responsable) VALUES (@pid5,6,1);
INSERT INTO documentos (proyecto_id,tipo,version,url,nombre_archivo,subido_por) VALUES
(@pid5,'Propuesta_FDC124',1,'https://drive.google.com/file/d/1vwx/view','Propuesta.pdf',6),
(@pid5,'Turnitin_FDC124',1,'https://drive.google.com/file/d/1yzA/view','Turnitin_Prop.pdf',6),
(@pid5,'Informe_FDC125',1,'https://drive.google.com/file/d/1bcd/view','Informe_Final.pdf',6),
(@pid5,'Turnitin_FDC125',1,'https://drive.google.com/file/d/1efg/view','Turnitin_Informe.pdf',6),
(@pid5,'Rejilla_FDC129',1,'https://drive.google.com/file/d/1hij/view','Rejilla_Final.pdf',6);

-- Respuestas completas proyecto 5
INSERT INTO respuestas (proyecto_id,fase,usuario_id,rol,estado,acta_numero,acta_fecha,comentario,
  codigo_modalidad,director_id,evaluador_id,informe_fdc125_url,rejilla_fdc129_url) VALUES
(@pid5,1,1,'comite','Aprobado','ACTA-2026-003','2026-08-25','Aprobado','125-2026-099',3,4,NULL,NULL),
(@pid5,2,3,'director','Aprobado','ACTA-2026-017','2026-09-15','Propuesta OK',NULL,NULL,NULL,NULL),
(@pid5,3,4,'evaluador','Aprobado','ACTA-2026-031','2026-09-28','Propuesta OK',NULL,NULL,NULL,NULL),
(@pid5,4,3,'director','Aprobado','ACTA-2026-045','2026-10-10','Informe aprobado',NULL,NULL,NULL,NULL),
(@pid5,5,1,'comite','Aprobado','ACTA-2026-060','2026-10-20','Sustentación aprobada',NULL,NULL,NULL,
 'https://drive.google.com/file/d/1bcd/view','https://drive.google.com/file/d/1hij/view');

-- Historial de ejemplo
INSERT INTO historial (proyecto_id,usuario_id,accion,fase,acta_numero,comentario) VALUES
(@pid5,1,'Aprobacion Fase 1',1,'ACTA-2026-003','Proyecto aprobado por comité'),
(@pid5,3,'Aprobacion Fase 2',2,'ACTA-2026-017','Director aprueba propuesta'),
(@pid5,4,'Aprobacion Fase 3',3,'ACTA-2026-031','Evaluador aprueba propuesta'),
(@pid5,3,'Aprobacion Fase 4',4,'ACTA-2026-045','Director aprueba informe'),
(@pid5,1,'Aprobacion Fase 5 / Sustentacion',5,'ACTA-2026-060','Comité aprueba sustentación');

-- Propuesta banco rechazada
INSERT INTO propuestas_banco (codigo,docente_id,titulo,tipo_modalidad,objetivo_general,
  linea_investigacion,tipo_nivel,periodo_id,estado,disponible,fecha_revision,comite_revisor_id,observacion_comite)
VALUES ('BAN-00003',5,'Sistema legacy sin innovación','Desarrollo tecnologico',
  'Migrar sistema viejo','Ingeniería de Software','Profesional',1,'Rechazada',0,
  '2026-08-10',1,'No cumple criterios de innovación requeridos');

-- Formatos de grado institucionales
INSERT INTO formatos (codigo, nombre, url, activo) VALUES
('F-DC-124', 'Formato Propuesta Trabajo de Grado (F-DC-124)', 'https://drive.google.com/file/d/uts-fdc124-plantilla/view', 1),
('F-DC-125', 'Formato Informe Final Trabajo de Grado (F-DC-125)', 'https://drive.google.com/file/d/uts-fdc125-plantilla/view', 1),
('F-DC-126', 'Formato Solicitud Comité de Grado (F-DC-126)', 'https://drive.google.com/file/d/uts-fdc126-plantilla/view', 1),
('F-DC-129', 'Rejilla de Calificación Evaluación de Grado (F-DC-129)', 'https://drive.google.com/file/d/uts-fdc129-plantilla/view', 1),
('F-DC-209', 'Formato de Seguimiento y Control de Anteproyecto (F-DC-209)', 'https://drive.google.com/file/d/uts-fdc209-plantilla/view', 1);