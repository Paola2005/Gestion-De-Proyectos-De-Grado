<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>

<c:set var="roles" value="${sessionScope.roles}" />
<%-- Rol con el que entró el usuario (elegido al iniciar sesión); sin él se deduce como antes --%>
<c:choose>
  <c:when test="${not empty sessionScope.rol_activo}"><c:set var="rolVista" value="${sessionScope.rol_activo}" /></c:when>
  <c:when test="${fn:contains(roles,'comite')}"><c:set var="rolVista" value="comite" /></c:when>
  <c:when test="${fn:contains(roles,'administrador')}"><c:set var="rolVista" value="administrador" /></c:when>
  <c:when test="${fn:contains(roles,'docente')}"><c:set var="rolVista" value="docente" /></c:when>
  <c:otherwise><c:set var="rolVista" value="estudiante" /></c:otherwise>
</c:choose>
<c:set var="tieneComite" value="${rolVista == 'comite'}" />
<c:set var="tieneAdministrador" value="${rolVista == 'administrador'}" />
<c:set var="tieneDocente" value="${rolVista == 'docente'}" />
<c:set var="tieneEstudiante" value="${rolVista == 'estudiante'}" />
<sql:query dataSource="${db}" var="cuentaRoles">
  SELECT COUNT(*) AS n FROM usuario_rol WHERE usuario_id = ?
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Inicio - SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
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
      <sql:query dataSource="${db}" var="perActIni">SELECT codigo FROM periodos WHERE activo=1 LIMIT 1</sql:query>
      <div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-2">
        <div>
          <h2 class="page-title">
            Panel <span class="badge-title-box">PRINCIPAL</span>
          </h2>
          <p class="text-muted small mb-0">Sistema de Gestión y Seguimiento de Trabajos de Grado · Rol activo: <strong class="text-capitalize">${rolVista}</strong>
            <c:if test="${cuentaRoles.rows[0].n > 1}">
              <a href="${pageContext.request.contextPath}/elegir_rol.jsp" class="ms-2 small">Cambiar de rol</a>
            </c:if>
          </p>
        </div>
        <div class="text-end">
          <span class="badge bg-light text-dark border px-3 py-2">
            <i class="fas fa-calendar-alt text-muted me-1"></i> Periodo Activo: <strong>${perActIni.rowCount > 0 ? perActIni.rows[0].codigo : 'Sin periodo activo'}</strong>
          </span>
        </div>
      </div>

      <%-- 1. VISTA DE INICIO PARA COMITÉ --%>
      <c:if test="${tieneComite}">
        <sql:query dataSource="${db}" var="metricasComite">
          SELECT 
            (SELECT COUNT(*) FROM propuestas_banco WHERE estado = 'Pendiente') AS banco_pendientes,
            (SELECT COUNT(*) FROM proyectos WHERE fase = 1 AND responsable = 'comite') AS fase1_pendientes,
            (SELECT COUNT(*) FROM proyectos WHERE fase = 5 AND responsable = 'comite') AS fase5_pendientes,
            (SELECT COUNT(*) FROM proyectos) AS total_proyectos
        </sql:query>

        <div class="row g-3 mb-4">
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Propuestas Banco Pendientes</div>
                  <div class="fs-4 fw-bold text-warning">${metricasComite.rows[0].banco_pendientes}</div>
                </div>
                <div class="btn-icon-sq btn-icon-eye" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-lightbulb"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Fase 1 Por Asignar</div>
                  <div class="fs-4 fw-bold text-primary">${metricasComite.rows[0].fase1_pendientes}</div>
                </div>
                <div class="btn-icon-sq btn-icon-map" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-user-plus"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Fase 5 Dictamen Final</div>
                  <div class="fs-4 fw-bold text-danger">${metricasComite.rows[0].fase5_pendientes}</div>
                </div>
                <div class="btn-icon-sq btn-icon-reply" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-award"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Total Proyectos Registrados</div>
                  <div class="fs-4 fw-bold text-dark">${metricasComite.rows[0].total_proyectos}</div>
                </div>
                <div class="btn-icon-sq btn-icon-doc" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-project-diagram"></i>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="row g-3">
          <div class="col-md-6 col-lg-3">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-eye" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-lightbulb"></i>
              </div>
              <h5 class="fw-bold">Propuestas <span class="badge-title-box" style="font-size: 0.9rem;">BANCO</span></h5>
              <p class="text-muted small flex-grow-1">Revisar, aprobar o rechazar ideas radicadas por los docentes.</p>
              <a href="${pageContext.request.contextPath}/comite/banco.jsp" class="btn btn-uts btn-sm w-100">Gestionar Propuestas</a>
            </div>
          </div>
          <div class="col-md-6 col-lg-3">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-map" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-project-diagram"></i>
              </div>
              <h5 class="fw-bold">Proyectos de <span class="badge-title-box" style="font-size: 0.9rem;">GRADO</span></h5>
              <p class="text-muted small flex-grow-1">Bandeja maestra, asignación de tribunales, códigos 125/65 y actas.</p>
              <a href="${pageContext.request.contextPath}/comite/proyectos.jsp" class="btn btn-uts btn-sm w-100">Gestionar Proyectos</a>
            </div>
          </div>
          <div class="col-md-6 col-lg-3">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-doc" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-calendar-alt"></i>
              </div>
              <h5 class="fw-bold">Calendario <span class="badge-title-box" style="font-size: 0.9rem;">ACADÉMICO</span></h5>
              <p class="text-muted small flex-grow-1">Configurar plazos de calendario para propuestas y proyectos.</p>
              <a href="${pageContext.request.contextPath}/comun/calendario.jsp" class="btn btn-uts btn-sm w-100">Configuración</a>
            </div>
          </div>
          <div class="col-md-6 col-lg-3">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-reply" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-file-pdf"></i>
              </div>
              <h5 class="fw-bold">Formatos de <span class="badge-title-box" style="font-size: 0.9rem;">GRADO</span></h5>
              <p class="text-muted small flex-grow-1">Crear, editar y eliminar formatos institucionales.</p>
              <a href="${pageContext.request.contextPath}/comun/formatos.jsp" class="btn btn-uts btn-sm w-100">Formatos</a>
            </div>
          </div>
        </div>
      </c:if>

      <%-- 2. VISTA DE INICIO PARA DOCENTE (Módulos Director y Evaluador) --%>
      <c:if test="${tieneDocente}">
        <sql:query dataSource="${db}" var="metricasDoc">
          SELECT 
            (SELECT COUNT(*) FROM proyectos WHERE director_id = ? AND responsable = 'director') AS dir_pendientes,
            (SELECT COUNT(*) FROM proyectos WHERE director_id = ?) AS dir_totales,
            (SELECT COUNT(*) FROM proyectos WHERE evaluador_id = ? AND responsable = 'evaluador') AS eval_pendientes,
            (SELECT COUNT(*) FROM proyectos WHERE evaluador_id = ?) AS eval_totales,
            (SELECT COUNT(*) FROM propuestas_banco WHERE docente_id = ?) AS mis_propuestas
          <sql:param value="${sessionScope.usuario_id}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:query>

        <div class="row g-3 mb-4">
          <div class="col-md-4">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Revisiones como Director</div>
                  <div class="fs-4 fw-bold text-primary">${metricasDoc.rows[0].dir_pendientes} pendientes</div>
                  <div class="small text-muted">${metricasDoc.rows[0].dir_totales} asignados en total</div>
                </div>
                <div class="btn-icon-sq btn-icon-eye" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-chalkboard-teacher"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Revisiones como Evaluador</div>
                  <div class="fs-4 fw-bold text-warning">${metricasDoc.rows[0].eval_pendientes} pendientes</div>
                  <div class="small text-muted">${metricasDoc.rows[0].eval_totales} asignados en total</div>
                </div>
                <div class="btn-icon-sq btn-icon-map" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-clipboard-check"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Mis Propuestas en Banco</div>
                  <div class="fs-4 fw-bold text-success">${metricasDoc.rows[0].mis_propuestas} registradas</div>
                  <div class="small text-muted">Ideas institucionales radicadas</div>
                </div>
                <div class="btn-icon-sq btn-icon-doc" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-lightbulb"></i>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="row g-3">
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-eye" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-chalkboard-teacher"></i>
              </div>
              <h5 class="fw-bold">Docente <span class="badge-title-box" style="font-size: 0.9rem;">DIRECTOR</span></h5>
              <p class="text-muted small flex-grow-1">Revisar Propuesta I (Fase 2) e Informe I (Fase 4), verificar Turnitin y remitir al evaluador.</p>
              <a href="${pageContext.request.contextPath}/docente/director.jsp" class="btn btn-uts btn-sm w-100">Bandeja Director</a>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-map" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-clipboard-check"></i>
              </div>
              <h5 class="fw-bold">Docente <span class="badge-title-box" style="font-size: 0.9rem;">EVALUADOR</span></h5>
              <p class="text-muted small flex-grow-1">Evaluar Propuesta II (Fase 3) e Informe II (Fase 5), registrar rejilla de calificación y dictámenes.</p>
              <a href="${pageContext.request.contextPath}/docente/evaluador.jsp" class="btn btn-uts btn-sm w-100">Bandeja Evaluador</a>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-doc" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-lightbulb"></i>
              </div>
              <h5 class="fw-bold">Banco de <span class="badge-title-box" style="font-size: 0.9rem;">IDEAS</span></h5>
              <p class="text-muted small flex-grow-1">Publicar nuevas propuestas para asignación de estudiantes en trabajos de grado.</p>
              <a href="${pageContext.request.contextPath}/docente/banco.jsp" class="btn btn-uts btn-sm w-100">Mis Propuestas</a>
            </div>
          </div>
        </div>
      </c:if>

      <%-- 3. VISTA DE INICIO PARA ESTUDIANTE --%>
      <c:if test="${tieneEstudiante}">
        <sql:query dataSource="${db}" var="proyEst">
          SELECT p.id, p.codigo, p.titulo, p.fase, p.responsable, p.estado,
                 u_dir.nombres AS dir_nom, u_dir.apellidos AS dir_ape,
                 u_cod.nombres AS cod_nom, u_cod.apellidos AS cod_ape
          FROM proyectos p
          INNER JOIN proyecto_integrantes pi ON p.id = pi.proyecto_id
          LEFT JOIN usuarios u_dir ON p.director_id = u_dir.id
          LEFT JOIN usuarios u_cod ON p.codirector_id = u_cod.id
          WHERE pi.usuario_id = ?
          LIMIT 1
          <sql:param value="${sessionScope.usuario_id}"/>
        </sql:query>

        <c:choose>
          <c:when test="${proyEst.rowCount > 0}">
            <c:set var="miProy" value="${proyEst.rows[0]}" />
            <div class="card-sigrado p-4 mb-4">
              <div class="row align-items-center">
                <div class="col-md-8">
                  <span class="badge bg-light text-dark border mb-2">Código: <strong>${miProy.codigo}</strong></span>
                  <h4 class="fw-bold text-dark mb-2">${miProy.titulo}</h4>
                  <p class="text-muted small mb-2">
                    <strong>Director Asignado:</strong> 
                    <c:choose>
                      <c:when test="${not empty miProy.dir_nom}">${miProy.dir_nom} ${miProy.dir_ape}</c:when>
                      <c:otherwise><em>Por asignar en Comité</em></c:otherwise>
                    </c:choose>
                    <c:if test="${not empty miProy.cod_nom}">
                      | <strong>Codirector:</strong> ${miProy.cod_nom} ${miProy.cod_ape}
                    </c:if>
                  </p>
                  <%-- RESTRICCIÓN OBLIGATORIA: Nunca mostrar nombre del evaluador --%>
                </div>
                <div class="col-md-4 text-md-end">
                  <div class="mb-2">
                    <span class="badge-fase-dual">
                      <span class="fase-tag">Fase ${miProy.fase}</span>
                      <span class="actor-tag text-uppercase">${miProy.responsable}</span>
                    </span>
                  </div>
                  <div class="small text-muted mb-2">Estado: <strong>${miProy.estado}</strong></div>
                  <a href="${pageContext.request.contextPath}/estudiante/proyecto.jsp" class="btn btn-uts btn-sm">Ver Proyecto Completo</a>
                </div>
              </div>
            </div>
          </c:when>
          <c:otherwise>
            <div class="card-sigrado p-4 mb-4 text-center">
              <i class="fas fa-folder-open text-muted fa-3x mb-3"></i>
              <h5>No tienes un proyecto de grado vinculado</h5>
              <p class="text-muted small">Comunícate con la administración o el comité para tu registro en el sistema.</p>
            </div>
          </c:otherwise>
        </c:choose>

        <div class="row g-3">
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-eye" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-graduation-cap"></i>
              </div>
              <h5 class="fw-bold">Mi <span class="badge-title-box" style="font-size: 0.9rem;">PROYECTO</span></h5>
              <p class="text-muted small flex-grow-1">Información general, integrantes y docentes de acompañamiento.</p>
              <a href="${pageContext.request.contextPath}/estudiante/proyecto.jsp" class="btn btn-uts btn-sm w-100">Consultar</a>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-map" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-tasks"></i>
              </div>
              <h5 class="fw-bold">Seguimiento de <span class="badge-title-box" style="font-size: 0.9rem;">FASES</span></h5>
              <p class="text-muted small flex-grow-1">Mapa interactivo con las 6 fases y el progreso cronológico del grado.</p>
              <c:choose>
                <c:when test="${proyEst.rowCount > 0}">
                  <a href="${pageContext.request.contextPath}/estudiante/seguimiento.jsp?id=${miProy.id}" class="btn btn-uts btn-sm w-100">Ver Seguimiento</a>
                </c:when>
                <c:otherwise>
                  <button class="btn btn-secondary btn-sm w-100" disabled>Sin proyecto activo</button>
                </c:otherwise>
              </c:choose>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-reply" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-file-upload"></i>
              </div>
              <h5 class="fw-bold">Entregas y <span class="badge-title-box" style="font-size: 0.9rem;">VERSIONES</span></h5>
              <p class="text-muted small flex-grow-1">Radicar documentos (F-DC-124, Turnitin, F-DC-125) y consultar correcciones.</p>
              <c:choose>
                <c:when test="${proyEst.rowCount > 0}">
                  <a href="${pageContext.request.contextPath}/estudiante/versiones.jsp?id=${miProy.id}" class="btn btn-uts btn-sm w-100">Radicar Entrega</a>
                </c:when>
                <c:otherwise>
                  <button class="btn btn-secondary btn-sm w-100" disabled>Sin proyecto activo</button>
                </c:otherwise>
              </c:choose>
            </div>
          </div>
        </div>
      </c:if>

      <%-- 4. VISTA DE INICIO PARA ADMINISTRADOR --%>
      <c:if test="${tieneAdministrador}">
        <sql:query dataSource="${db}" var="metricasAdmin">
          SELECT 
            COUNT(*) AS total,
            SUM(CASE WHEN estado = 'Finalizado' THEN 1 ELSE 0 END) AS finalizados,
            SUM(CASE WHEN estado = 'En curso' THEN 1 ELSE 0 END) AS en_proceso,
            SUM(CASE WHEN estado = 'Cancelado' THEN 1 ELSE 0 END) AS cancelados
          FROM proyectos
        </sql:query>

        <div class="row g-3 mb-4">
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Proyectos en Curso</div>
                  <div class="fs-4 fw-bold text-primary">${metricasAdmin.rows[0].en_proceso}</div>
                </div>
                <div class="btn-icon-sq btn-icon-map" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-tasks"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Proyectos Culminados</div>
                  <div class="fs-4 fw-bold text-success">${metricasAdmin.rows[0].finalizados}</div>
                </div>
                <div class="btn-icon-sq btn-icon-reply" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-check-circle"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Proyectos Cancelados</div>
                  <div class="fs-4 fw-bold text-secondary">${metricasAdmin.rows[0].cancelados}</div>
                </div>
                <div class="btn-icon-sq btn-icon-reply" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-ban"></i>
                </div>
              </div>
            </div>
          </div>
          <div class="col-md-3">
            <div class="card-sigrado p-3">
              <div class="d-flex align-items-center justify-content-between">
                <div>
                  <div class="text-muted small">Total Registrados</div>
                  <div class="fs-4 fw-bold text-dark">${metricasAdmin.rows[0].total}</div>
                </div>
                <div class="btn-icon-sq btn-icon-doc" style="width: 44px; height: 44px; font-size: 1.2rem;">
                  <i class="fas fa-chart-pie"></i>
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="row g-3">
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-eye" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-users-cog"></i>
              </div>
              <h5 class="fw-bold">Gestión de <span class="badge-title-box" style="font-size: 0.9rem;">USUARIOS</span></h5>
              <p class="text-muted small flex-grow-1">Crear, editar, activar/desactivar, asignar roles, eliminar usuarios.</p>
              <a href="${pageContext.request.contextPath}/comite/usuarios.jsp" class="btn btn-uts btn-sm w-100">Gestionar Usuarios</a>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-map" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-project-diagram"></i>
              </div>
              <h5 class="fw-bold">Proyectos de <span class="badge-title-box" style="font-size: 0.9rem;">GRADO</span></h5>
              <p class="text-muted small flex-grow-1">Listar todos, filtrar, ver detalle, reasignar tribunal, cancelar con motivo.</p>
              <a href="${pageContext.request.contextPath}/administrador/proyectos.jsp" class="btn btn-uts btn-sm w-100">Gestionar Proyectos</a>
            </div>
          </div>
          <div class="col-md-4">
            <div class="card-sigrado p-4 h-100 d-flex flex-column text-center">
              <div class="mx-auto mb-3 btn-icon-sq btn-icon-doc" style="width: 50px; height: 50px; font-size: 1.4rem;">
                <i class="fas fa-sliders-h"></i>
              </div>
              <h5 class="fw-bold"><span class="badge-title-box" style="font-size: 0.9rem;">CONFIGURACIÓN</span></h5>
              <p class="text-muted small flex-grow-1">Generar y descargar copia de seguridad, formatos de grado.</p>
              <a href="${pageContext.request.contextPath}/administrador/configuracion.jsp" class="btn btn-uts btn-sm w-100">Configuración</a>
            </div>
          </div>
        </div>
      </c:if>

    </div>
  </div>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>