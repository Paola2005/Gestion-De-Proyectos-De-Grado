<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardEstudiante.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<%-- ====================================================
     ACCIÓN: Seleccionar idea del banco y radicar proyecto
     ==================================================== --%>
<c:if test="${param.accion == 'seleccionar' and not empty param.idea_id}">
  <c:set var="s1ok" value="${not empty param.soporte1 and fn:startsWith(param.soporte1,'https://')}"/>
  <c:if test="${not s1ok}">
    <c:redirect url="/estudiante/banco.jsp">
      <c:param name="error" value="El soporte de pago 1 debe ser una URL válida (https://)"/>
    </c:redirect>
  </c:if>
  <%-- Las acciones respetan las fechas del periodo activo --%>
  <sql:query dataSource="${db}" var="ventanaSel">
    SELECT (CURDATE() BETWEEN inicio_nuevos_proyectos AND fin_aprobacion_propuesta) AS en_ventana
    FROM periodos WHERE activo = 1 LIMIT 1
  </sql:query>
  <c:if test="${ventanaSel.rowCount == 0 or ventanaSel.rows[0].en_ventana != 1}">
    <c:redirect url="/estudiante/banco.jsp">
      <c:param name="error" value="Fuera de las fechas del periodo activo. No se pueden inscribir proyectos."/>
    </c:redirect>
  </c:if>

  <c:catch var="errSelec">
    <sql:transaction dataSource="${db}">
      <%-- Verificar que no tenga proyecto activo --%>
      <sql:query var="tieneProyecto">
        SELECT COUNT(*) AS c
        FROM proyecto_integrantes pi
        JOIN proyectos p ON pi.proyecto_id = p.id
        WHERE pi.usuario_id = ?
          AND p.estado NOT IN ('Rechazado','Finalizado','Cancelado')
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:query>
      <c:if test="${tieneProyecto.rows[0].c > 0}">
        <c:redirect url="/estudiante/banco.jsp">
          <c:param name="error" value="Ya tienes un proyecto activo. No puedes inscribir otro."/>
        </c:redirect>
      </c:if>

      <%-- Verificar que la idea sigue disponible --%>
      <sql:query var="ideaDisp">
        SELECT COUNT(*) AS c FROM propuestas_banco WHERE id=? AND disponible=1 AND estado='Aprobada'
        <sql:param value="${param.idea_id}"/>
      </sql:query>
      <c:if test="${ideaDisp.rows[0].c == 0}">
        <c:redirect url="/estudiante/banco.jsp">
          <c:param name="error" value="La idea seleccionada ya no está disponible."/>
        </c:redirect>
      </c:if>

      <%-- Verificar compañero (si aplica) --%>
      <c:if test="${not empty param.companero_id}">
        <sql:query var="compOk">
          SELECT COUNT(*) AS c FROM usuarios u
          WHERE u.id = ?
            AND u.activo = 1
            AND u.id NOT IN (
              SELECT pi2.usuario_id FROM proyecto_integrantes pi2
              JOIN proyectos p2 ON pi2.proyecto_id = p2.id
              WHERE p2.estado NOT IN ('Rechazado','Finalizado','Cancelado')
            )
          <sql:param value="${param.companero_id}"/>
        </sql:query>
        <c:if test="${compOk.rows[0].c == 0}">
          <c:redirect url="/estudiante/banco.jsp">
            <c:param name="error" value="El compañero seleccionado ya tiene un proyecto activo o no existe."/>
          </c:redirect>
        </c:if>
      </c:if>

      <%-- Obtener datos de la idea del banco (propuestas_banco no tiene columna descripcion) --%>
      <sql:query var="ideaInfo">
        SELECT titulo, objetivo_general, tipo_modalidad, tipo_nivel
        FROM propuestas_banco WHERE id=?
        <sql:param value="${param.idea_id}"/>
      </sql:query>

      <%-- Obtener periodo activo --%>
      <sql:query var="perActivo">
        SELECT id FROM periodos WHERE activo=1 LIMIT 1
      </sql:query>
      <c:set var="periodoId" value="${perActivo.rows[0].id}"/>

      <%-- Insertar proyecto con código consecutivo único (descripcion = objetivo_general, no existe en banco) --%>
      <sql:update>
        INSERT INTO proyectos (
          codigo, banco_id, titulo, objetivo_general, descripcion,
          tipo_idea, tipo_modalidad, tipo_nivel, periodo_id,
          fase, responsable, estado
        )
        SELECT
          CONCAT('GRA-', LPAD(COALESCE((SELECT MAX(CAST(SUBSTRING(codigo,5) AS UNSIGNED)) FROM proyectos WHERE codigo LIKE 'GRA-%'),0)+1, 5, '0')),
          ?, ?, ?, ?, 'Banco', ?, ?, ?, 1, 'comite', 'En curso'
        <sql:param value="${param.idea_id}"/>
        <sql:param value="${ideaInfo.rows[0].titulo}"/>
        <sql:param value="${ideaInfo.rows[0].objetivo_general}"/>
        <sql:param value="${ideaInfo.rows[0].objetivo_general}"/>
        <sql:param value="${ideaInfo.rows[0].tipo_modalidad}"/>
        <sql:param value="${ideaInfo.rows[0].tipo_nivel}"/>
        <sql:param value="${periodoId}"/>
      </sql:update>
      <sql:query var="newProy">SELECT LAST_INSERT_ID() AS id</sql:query>
      <c:set var="proyId" value="${newProy.rows[0].id}"/>

      <%-- Integrante responsable --%>
      <sql:update>
        INSERT INTO proyecto_integrantes (proyecto_id, usuario_id, es_responsable)
        VALUES (?, ?, 1)
        <sql:param value="${proyId}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>

      <%-- Compañero (opcional) --%>
      <c:if test="${not empty param.companero_id}">
        <sql:update>
          INSERT INTO proyecto_integrantes (proyecto_id, usuario_id, es_responsable)
          VALUES (?, ?, 0)
          <sql:param value="${proyId}"/>
          <sql:param value="${param.companero_id}"/>
        </sql:update>
      </c:if>

      <%-- Soporte de pago 1 --%>
      <sql:update>
        INSERT INTO documentos (proyecto_id, tipo, version, url, nombre_archivo, fase, subido_por)
        VALUES (?, 'SoportePago', 1, ?, 'Soporte de pago', 1, ?)
        <sql:param value="${proyId}"/>
        <sql:param value="${param.soporte1}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>

      <%-- Soporte de pago 2 (si hay compañero y se adjuntó) --%>
      <c:if test="${not empty param.soporte2 and not empty param.companero_id and fn:startsWith(param.soporte2,'https://')}">
        <sql:update>
          INSERT INTO documentos (proyecto_id, tipo, version, url, nombre_archivo, fase, subido_por)
          VALUES (?, 'SoportePago', 2, ?, 'Soporte de pago (compañero)', 1, ?)
          <sql:param value="${proyId}"/>
          <sql:param value="${param.soporte2}"/>
          <sql:param value="${param.companero_id}"/>
        </sql:update>
      </c:if>

      <%-- Marcar idea como no disponible --%>
      <sql:update>
        UPDATE propuestas_banco SET disponible = 0 WHERE id = ?
        <sql:param value="${param.idea_id}"/>
      </sql:update>

      <%-- Historial --%>
      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
        VALUES (?, ?, 'Inscripción desde Banco de Ideas', 1,
          'Estudiante seleccionó idea del banco y adjuntó comprobante de pago. Pendiente de revisión por el Comité.')
        <sql:param value="${proyId}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>
    </sql:transaction>
  </c:catch>
  <c:choose>
    <c:when test="${not empty errSelec}">
      <c:redirect url="/estudiante/banco.jsp">
        <c:param name="error" value="Error al inscribir el proyecto. Intenta de nuevo."/>
      </c:redirect>
    </c:when>
    <c:otherwise>
      <c:redirect url="/estudiante/proyecto.jsp">
        <c:param name="ok" value="¡Proyecto inscrito correctamente! Tu solicitud está en Fase 1 pendiente de revisión del Comité."/>
      </c:redirect>
    </c:otherwise>
  </c:choose>
</c:if>

<%-- ====================================================
     ACCIÓN: Proponer idea propia y radicar proyecto
     ==================================================== --%>
<c:if test="${param.accion == 'proponer'}">
  <c:set var="errForm" value=""/>
  <c:if test="${empty param.titulo}"><c:set var="errForm" value="El título es obligatorio. "/></c:if>
  <c:if test="${empty param.objetivo}"><c:set var="errForm" value="${errForm}El objetivo general es obligatorio. "/></c:if>
  <c:if test="${empty param.descripcion}"><c:set var="errForm" value="${errForm}La descripción es obligatoria. "/></c:if>
  <c:if test="${empty param.modalidad}"><c:set var="errForm" value="${errForm}La modalidad es obligatoria. "/></c:if>
  <c:if test="${empty param.nivel}"><c:set var="errForm" value="${errForm}El nivel académico es obligatorio. "/></c:if>
  <c:if test="${empty param.soporte1 or not fn:startsWith(param.soporte1,'https://')}">
    <c:set var="errForm" value="${errForm}El soporte de pago debe ser una URL válida (https://). "/>
  </c:if>
  <c:if test="${not empty param.soporte2 and not fn:startsWith(param.soporte2,'https://')}">
    <c:set var="errForm" value="${errForm}El soporte de pago del compañero debe ser una URL válida (https://). "/>
  </c:if>
  <c:if test="${not empty errForm}">
    <c:redirect url="/estudiante/banco.jsp">
      <c:param name="error" value="${errForm}"/>
      <c:param name="form_titulo"     value="${param.titulo}"/>
      <c:param name="form_objetivo"   value="${param.objetivo}"/>
      <c:param name="form_descripcion" value="${param.descripcion}"/>
      <c:param name="form_modalidad"  value="${param.modalidad}"/>
      <c:param name="form_nivel"      value="${param.nivel}"/>
    </c:redirect>
  </c:if>

  <c:catch var="errPropia">
    <%-- Las acciones respetan las fechas del periodo activo --%>
    <sql:query var="ventanaProp">
      SELECT (CURDATE() BETWEEN inicio_nuevos_proyectos AND fin_aprobacion_propuesta) AS en_ventana
      FROM periodos WHERE activo = 1 LIMIT 1
    </sql:query>
    <c:if test="${ventanaProp.rowCount == 0 or ventanaProp.rows[0].en_ventana != 1}">
      <c:redirect url="/estudiante/banco.jsp">
        <c:param name="error" value="Fuera de las fechas del periodo activo. No se pueden radicar propuestas."/>
      </c:redirect>
    </c:if>
    <sql:transaction dataSource="${db}">
      <sql:query var="tieneProyecto">
        SELECT COUNT(*) AS c
        FROM proyecto_integrantes pi
        JOIN proyectos p ON pi.proyecto_id = p.id
        WHERE pi.usuario_id = ?
          AND p.estado NOT IN ('Rechazado','Finalizado','Cancelado')
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:query>
      <c:if test="${tieneProyecto.rows[0].c > 0}">
        <c:redirect url="/estudiante/banco.jsp">
          <c:param name="error" value="Ya tienes un proyecto activo. No puedes inscribir otro."/>
        </c:redirect>
      </c:if>

      <%-- Verificar compañero (si aplica) --%>
      <c:if test="${not empty param.companero_id}">
        <sql:query var="compOk2">
          SELECT COUNT(*) AS c FROM usuarios u
          WHERE u.id = ?
            AND u.activo = 1
            AND u.id NOT IN (
              SELECT pi2.usuario_id FROM proyecto_integrantes pi2
              JOIN proyectos p2 ON pi2.proyecto_id = p2.id
              WHERE p2.estado NOT IN ('Rechazado','Finalizado','Cancelado')
            )
          <sql:param value="${param.companero_id}"/>
        </sql:query>
        <c:if test="${compOk2.rows[0].c == 0}">
          <c:redirect url="/estudiante/banco.jsp">
            <c:param name="error" value="El compañero seleccionado ya tiene un proyecto activo o no existe."/>
          </c:redirect>
        </c:if>
      </c:if>

      <%-- Obtener periodo activo --%>
      <sql:query var="perActivo2">
        SELECT id FROM periodos WHERE activo=1 LIMIT 1
      </sql:query>
      <c:set var="periodoId2" value="${perActivo2.rows[0].id}"/>

      <%-- Insertar proyecto con código consecutivo --%>
      <sql:update>
        INSERT INTO proyectos (
          codigo, titulo, objetivo_general, descripcion,
          tipo_idea, tipo_modalidad, tipo_nivel, periodo_id,
          fase, responsable, estado
        )
        SELECT
          CONCAT('GRA-', LPAD(COALESCE((SELECT MAX(CAST(SUBSTRING(codigo,5) AS UNSIGNED)) FROM proyectos WHERE codigo LIKE 'GRA-%'),0)+1, 5, '0')),
          ?, ?, ?, 'Propia', ?, ?, ?, 1, 'comite', 'En curso'
        <sql:param value="${param.titulo}"/>
        <sql:param value="${param.objetivo}"/>
        <sql:param value="${param.descripcion}"/>
        <sql:param value="${param.modalidad}"/>
        <sql:param value="${param.nivel}"/>
        <sql:param value="${periodoId2}"/>
      </sql:update>
      <sql:query var="newProy2">SELECT LAST_INSERT_ID() AS id</sql:query>
      <c:set var="proyId2" value="${newProy2.rows[0].id}"/>

      <sql:update>
        INSERT INTO proyecto_integrantes (proyecto_id, usuario_id, es_responsable)
        VALUES (?, ?, 1)
        <sql:param value="${proyId2}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>

      <c:if test="${not empty param.companero_id}">
        <sql:update>
          INSERT INTO proyecto_integrantes (proyecto_id, usuario_id, es_responsable)
          VALUES (?, ?, 0)
          <sql:param value="${proyId2}"/>
          <sql:param value="${param.companero_id}"/>
        </sql:update>
      </c:if>

      <sql:update>
        INSERT INTO documentos (proyecto_id, tipo, version, url, nombre_archivo, fase, subido_por)
        VALUES (?, 'SoportePago', 1, ?, 'Soporte de pago', 1, ?)
        <sql:param value="${proyId2}"/>
        <sql:param value="${param.soporte1}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>

      <c:if test="${not empty param.soporte2 and not empty param.companero_id}">
        <sql:update>
          INSERT INTO documentos (proyecto_id, tipo, version, url, nombre_archivo, fase, subido_por)
          VALUES (?, 'SoportePago', 2, ?, 'Soporte de pago (compañero)', 1, ?)
          <sql:param value="${proyId2}"/>
          <sql:param value="${param.soporte2}"/>
          <sql:param value="${param.companero_id}"/>
        </sql:update>
      </c:if>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
        VALUES (?, ?, 'Inscripción con Idea Propia', 1,
          'Estudiante radicó propuesta propia y comprobante de pago. Pendiente de aprobación por el Comité.')
        <sql:param value="${proyId2}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
      </sql:update>
    </sql:transaction>
  </c:catch>
  <c:choose>
    <c:when test="${not empty errPropia}">
      <c:redirect url="/estudiante/banco.jsp">
        <c:param name="error" value="Error al radicar la propuesta. Intenta de nuevo."/>
      </c:redirect>
    </c:when>
    <c:otherwise>
      <c:redirect url="/estudiante/proyecto.jsp">
        <c:param name="ok" value="¡Propuesta radicada correctamente! Tu proyecto está en Fase 1 pendiente de aprobación por el Comité."/>
      </c:redirect>
    </c:otherwise>
  </c:choose>
</c:if>

<%-- ====================================================
     CONSULTAR DATOS PARA LA VISTA
     ==================================================== --%>
<sql:query dataSource="${db}" var="periodoActivo">
  SELECT id, codigo FROM periodos WHERE activo=1 LIMIT 1
</sql:query>
<c:set var="periodoId"     value="${periodoActivo.rowCount > 0 ? periodoActivo.rows[0].id   : 0}"/>
<c:set var="periodoCodigo" value="${periodoActivo.rowCount > 0 ? periodoActivo.rows[0].codigo : 'Sin periodo activo'}"/>

<sql:query dataSource="${db}" var="disponibles">
  SELECT pb.*, CONCAT(u.nombres, ' ', u.apellidos) AS docente_nombre
  FROM propuestas_banco pb
  JOIN usuarios u ON pb.docente_id = u.id
  WHERE pb.estado = 'Aprobada' AND pb.disponible = 1
  ORDER BY pb.fecha_propuesta DESC
</sql:query>

<sql:query dataSource="${db}" var="companeros">
  SELECT u.id, CONCAT(u.nombres, ' ', u.apellidos, ' — ', u.documento) AS nombre_doc
  FROM usuarios u
  INNER JOIN usuario_rol ur ON ur.usuario_id = u.id
  INNER JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'estudiante'
  WHERE u.activo = 1
    AND u.id != ?
    AND u.id NOT IN (
      SELECT pi.usuario_id FROM proyecto_integrantes pi
      JOIN proyectos p ON pi.proyecto_id = p.id
      WHERE p.estado NOT IN ('Rechazado','Finalizado','Cancelado')
    )
  ORDER BY u.apellidos, u.nombres
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<sql:query dataSource="${db}" var="miProyecto">
  SELECT p.id, p.codigo, p.titulo, p.fase, p.estado, p.responsable
  FROM proyectos p
  JOIN proyecto_integrantes pi ON pi.proyecto_id = p.id AND pi.es_responsable = 1
  WHERE pi.usuario_id = ?
    AND p.estado NOT IN ('Rechazado','Finalizado','Cancelado')
  LIMIT 1
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Banco de Ideas - Estudiante · SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">

      <%-- Alertas --%>
      <c:if test="${not empty param.error}">
        <div class="alert alert-danger alert-dismissible fade show" role="alert">
          <i class="fas fa-exclamation-circle me-2"></i><c:out value="${param.error}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show" role="alert">
          <i class="fas fa-check-circle me-2"></i><c:out value="${param.ok}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <%-- Aviso de proyecto activo --%>
      <c:if test="${miProyecto.rowCount > 0}">
        <div class="alert alert-info d-flex align-items-center justify-content-between flex-wrap gap-2 mb-4">
          <div>
            <i class="fas fa-info-circle me-2"></i>
            Tienes un proyecto activo: <strong>${miProyecto.rows[0].codigo}</strong> – ${miProyecto.rows[0].titulo}
            <span class="badge bg-primary ms-2">Fase ${miProyecto.rows[0].fase}</span>
          </div>
          <a href="${pageContext.request.contextPath}/estudiante/proyecto.jsp" class="btn btn-primary btn-sm">
            <i class="fas fa-folder-open me-1"></i> Ir a Mi Proyecto
          </a>
        </div>
      </c:if>

      <div class="row g-4">

        <%-- ======== IDEAS DISPONIBLES ======== --%>
        <div class="col-xl-8 col-lg-7">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <div>
                <h2 class="page-title">
                  Ideas <span class="badge-title-box">DISPONIBLES</span>
                </h2>
                <div class="small text-muted mt-1">
                  Periodo activo: <strong>${periodoCodigo}</strong>
                  — Selecciona una idea o propone la tuya propia.
                </div>
              </div>
              <span class="badge badge-uts">${disponibles.rowCount} idea${disponibles.rowCount == 1 ? '' : 's'}</span>
            </div>

            <div class="p-0">
              <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                  <thead class="table-light">
                    <tr>
                      <th style="width:15%">Código</th>
                      <th style="width:38%">Título</th>
                      <th style="width:20%">Docente</th>
                      <th style="width:17%">Modalidad / Nivel</th>
                      <th style="width:10%; text-align:center">Acción</th>
                    </tr>
                  </thead>
                  <tbody>
                    <c:forEach items="${disponibles.rows}" var="i">
                      <tr>
                        <td class="fw-bold text-dark">${i.codigo}</td>
                        <td>
                          <div class="fw-semibold text-dark text-wrap">${i.titulo}</div>
                          <c:if test="${not empty i.objetivo_general}">
                            <div class="small text-muted text-wrap mt-1">
                              ${fn:substring(i.objetivo_general, 0, 100)}${fn:length(i.objetivo_general) > 100 ? '…' : ''}
                            </div>
                          </c:if>
                        </td>
                        <td>
                          <small class="fw-semibold text-dark">${i.docente_nombre}</small>
                          <div class="small text-muted">${i.linea_investigacion}</div>
                        </td>
                        <td>
                          <span class="badge bg-secondary mb-1">${i.tipo_modalidad}</span>
                          <div><span class="badge bg-light text-dark border">${i.tipo_nivel}</span></div>
                        </td>
                        <td style="text-align:center">
                          <c:choose>
                            <c:when test="${miProyecto.rowCount > 0}">
                              <button type="button" class="btn-icon-sq"
                                      style="background:#e9ecef;color:#6c757d;cursor:not-allowed"
                                      title="Ya tienes un proyecto activo" disabled>
                                <i class="fas fa-lock"></i>
                              </button>
                            </c:when>
                            <c:otherwise>
                              <button type="button" class="btn-icon-sq btn-icon-map"
                                      data-bs-toggle="modal" data-bs-target="#seleccionar${i.id}"
                                      title="Seleccionar esta idea y radicar pago">
                                <i class="fas fa-check"></i>
                              </button>
                            </c:otherwise>
                          </c:choose>
                        </td>
                      </tr>
                    </c:forEach>

                    <c:if test="${disponibles.rowCount == 0}">
                      <tr>
                        <td colspan="5" class="text-center py-5 text-muted">
                          <i class="fas fa-lightbulb fa-2x mb-2 d-block text-warning"></i>
                          No hay ideas disponibles en el banco en este momento.<br>
                          <small>Puedes proponer tu propia idea en el formulario a la derecha.</small>
                        </td>
                      </tr>
                    </c:if>
                  </tbody>
                </table>
              </div>
            </div>

            <c:if test="${miProyecto.rowCount > 0}">
              <div class="p-3 bg-light border-top rounded-bottom">
                <small class="text-muted">
                  <i class="fas fa-lock me-1"></i>
                  Opciones bloqueadas: ya tienes un proyecto activo (<strong>${miProyecto.rows[0].codigo}</strong>).
                </small>
              </div>
            </c:if>
          </div>
        </div>

        <%-- ======== PROPONER IDEA PROPIA ======== --%>
        <div class="col-xl-4 col-lg-5">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <h2 class="page-title">
                Proponer Idea <span class="badge-title-box">PROPIA</span>
              </h2>
            </div>

            <div class="p-4">
              <c:choose>
                <c:when test="${miProyecto.rowCount > 0}">
                  <div class="text-center text-muted py-5">
                    <i class="fas fa-lock fa-3x mb-3 text-secondary"></i>
                    <h6 class="fw-bold text-dark">Proyecto en curso</h6>
                    <p class="small mb-0">
                      Ya tienes el proyecto <strong>${miProyecto.rows[0].codigo}</strong> activo.
                      Solo puedes tener un trabajo de grado a la vez.
                    </p>
                  </div>
                </c:when>
                <c:otherwise>
                  <form method="post" action="banco.jsp" class="row g-3" novalidate>
                    <input type="hidden" name="accion" value="proponer"/>

                    <div class="col-12">
                      <label class="form-label small fw-bold">Título del proyecto <span class="text-danger">*</span></label>
                      <input type="text" name="titulo" class="form-control form-control-sm" required
                             placeholder="Nombre descriptivo de la propuesta"
                             value="${param.form_titulo}">
                    </div>

                    <div class="col-md-6">
                      <label class="form-label small fw-bold">Modalidad <span class="text-danger">*</span></label>
                      <select name="modalidad" class="form-select form-select-sm" required>
                        <option value="">Seleccione</option>
                        <option value="Desarrollo tecnologico" ${param.form_modalidad == 'Desarrollo tecnologico' ? 'selected' : ''}>Desarrollo tecnológico</option>
                        <option value="Emprendimiento"         ${param.form_modalidad == 'Emprendimiento'         ? 'selected' : ''}>Emprendimiento</option>
                        <option value="Investigacion"          ${param.form_modalidad == 'Investigacion'          ? 'selected' : ''}>Investigación</option>
                        <option value="Otro"                   ${param.form_modalidad == 'Otro'                   ? 'selected' : ''}>Otro</option>
                      </select>
                    </div>

                    <div class="col-md-6">
                      <label class="form-label small fw-bold">Nivel académico <span class="text-danger">*</span></label>
                      <select name="nivel" class="form-select form-select-sm" required>
                        <option value="">Seleccione</option>
                        <option value="Tecnologico"  ${param.form_nivel == 'Tecnologico'  ? 'selected' : ''}>Tecnológico</option>
                        <option value="Profesional"  ${param.form_nivel == 'Profesional'  ? 'selected' : ''}>Profesional</option>
                      </select>
                    </div>

                    <div class="col-12">
                      <label class="form-label small fw-bold">Objetivo General <span class="text-danger">*</span></label>
                      <textarea name="objetivo" class="form-control form-control-sm" rows="2" required
                                placeholder="Objetivo general del trabajo de grado"><c:out value="${param.form_objetivo}"/></textarea>
                    </div>

                    <div class="col-12">
                      <label class="form-label small fw-bold">Descripción / Justificación <span class="text-danger">*</span></label>
                      <textarea name="descripcion" class="form-control form-control-sm" rows="3" required
                                placeholder="Alcance, problemática y solución planteada"><c:out value="${param.form_descripcion}"/></textarea>
                    </div>

                    <div class="col-12">
                      <label class="form-label small fw-bold">
                        Soporte de Pago — URL Drive/OneDrive <span class="text-danger">*</span>
                      </label>
                      <input type="url" name="soporte1" class="form-control form-control-sm" required
                             placeholder="https://drive.google.com/file/d/…">
                      <div class="form-text">URL del comprobante de pago de derechos de grado.</div>
                    </div>

                    <div class="col-12">
                      <label class="form-label small fw-bold">Compañero <span class="text-muted">(opcional)</span></label>
                      <select name="companero_id" class="form-select form-select-sm" id="compPropio">
                        <option value="">Sin compañero (Individual)</option>
                        <c:forEach items="${companeros.rows}" var="c">
                          <option value="${c.id}">${c.nombre_doc}</option>
                        </c:forEach>
                      </select>
                    </div>

                    <div class="col-12" id="soporte2BoxPropio" style="display:none">
                      <label class="form-label small fw-bold">
                        Soporte de pago del compañero — URL <span class="text-muted">(opcional)</span>
                      </label>
                      <input type="url" name="soporte2" class="form-control form-control-sm"
                             placeholder="https://drive.google.com/file/d/…">
                    </div>

                    <div class="col-12 pt-2">
                      <button type="submit" class="btn btn-uts btn-sm w-100 py-2">
                        <i class="fas fa-paper-plane me-1"></i> Radicar Proyecto con Idea Propia
                      </button>
                    </div>
                  </form>
                  <script>
                    document.addEventListener('DOMContentLoaded', function() {
                      document.getElementById('compPropio')?.addEventListener('change',function(){
                        document.getElementById('soporte2BoxPropio').style.display=this.value?'block':'none';
                      });
                    });
                  </script>
                </c:otherwise>
              </c:choose>
            </div>
          </div>
        </div>

      </div><%-- /row --%>

      <%-- Modales "Inscribir" (uno por idea): fuera de la tabla para que el
           fondo oscuro, el centrado y el scroll interno funcionen siempre. --%>
      <c:if test="${miProyecto.rowCount == 0}">
        <c:forEach items="${disponibles.rows}" var="i">
          <div class="modal fade modal-inscribir" id="seleccionar${i.id}" tabindex="-1" aria-labelledby="inscribirTitulo${i.id}" aria-hidden="true">
            <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable">
              <form method="post" action="banco.jsp" class="modal-content">
                <input type="hidden" name="accion" value="seleccionar"/>
                <input type="hidden" name="idea_id" value="${i.id}"/>

                <div class="modal-header">
                  <h5 class="modal-title fw-bold" id="inscribirTitulo${i.id}">
                    Inscribir: <span class="badge-title-box">${i.codigo}</span>
                  </h5>
                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                </div>

                <div class="modal-body">
                  <div class="alert alert-info small mb-3">
                    <i class="fas fa-info-circle me-1"></i>
                    Tu proyecto quedará en <strong>Fase 1 · Comité</strong>. Debes adjuntar la URL
                    de tu comprobante de pago de derechos de grado (Drive, OneDrive, etc.).
                  </div>

                  <div class="mb-3">
                    <label class="form-label fw-bold small">Título del proyecto</label>
                    <input type="text" class="form-control form-control-sm"
                           value="${i.titulo}" readonly>
                  </div>

                  <div class="mb-3">
                    <label class="form-label fw-bold small" for="soporte1_${i.id}">
                      Soporte de pago — URL Drive/OneDrive <span class="text-danger">*</span>
                    </label>
                    <input type="url" id="soporte1_${i.id}" name="soporte1" class="form-control form-control-sm"
                           required placeholder="https://drive.google.com/file/d/…">
                    <div class="form-text">Tu comprobante de pago de derechos de grado.</div>
                  </div>

                  <div class="mb-3" id="soporte2box${i.id}" style="display:none">
                    <label class="form-label fw-bold small" for="soporte2_${i.id}">
                      Soporte de pago del compañero — URL Drive/OneDrive
                      <span class="text-muted">(opcional)</span>
                    </label>
                    <input type="url" id="soporte2_${i.id}" name="soporte2" class="form-control form-control-sm"
                           placeholder="https://drive.google.com/file/d/…">
                    <div class="form-text">Comprobante del segundo integrante.</div>
                  </div>

                  <div class="mb-3">
                    <label class="form-label fw-bold small" for="comp${i.id}">
                      Compañero de proyecto <span class="text-muted">(opcional)</span>
                    </label>
                    <select name="companero_id" class="form-select form-select-sm companion-select" id="comp${i.id}" data-soporte2="soporte2box${i.id}">
                      <option value="">Individual (sin compañero)</option>
                      <c:forEach items="${companeros.rows}" var="c">
                        <option value="${c.id}">${c.nombre_doc}</option>
                      </c:forEach>
                    </select>
                  </div>
                </div>

                <div class="modal-footer">
                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">
                    <i class="fas fa-times me-1"></i> Cancelar
                  </button>
                  <button type="submit" class="btn btn-uts btn-sm">
                    <i class="fas fa-paper-plane me-1"></i> Confirmar y Radicar Proyecto
                  </button>
                </div>
              </form>
            </div>
          </div>
        </c:forEach>
      </c:if>
      <script>
        document.addEventListener('DOMContentLoaded', function() {
          document.querySelectorAll('.companion-select').forEach(function(sel) {
            sel.addEventListener('change', function() {
              var box = document.getElementById(this.dataset.soporte2);
              if (box) { box.style.display = this.value ? 'block' : 'none'; }
            });
          });
        });
      </script>
    </div><%-- /main-content --%>

    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div><%-- /main-wrapper --%>
</body>
</html>