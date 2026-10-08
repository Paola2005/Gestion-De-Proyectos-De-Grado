<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardEstudiante.jspf" %>

<%-- Conteo y listado de proyectos del estudiante usando proyecto_integrantes --%>
<sql:query dataSource="${db}" var="proyectos">
  SELECT p.id, p.codigo, p.titulo, p.descripcion, p.estado, p.fase, p.responsable,
         p.tipo_modalidad, p.tipo_nivel,
         CONCAT(d.nombres, ' ', d.apellidos) AS director
  FROM proyectos p
  INNER JOIN proyecto_integrantes pi ON pi.proyecto_id = p.id
  LEFT JOIN usuarios d ON p.director_id = d.id
  WHERE pi.usuario_id = ?
  ORDER BY p.id DESC
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>
<c:set var="total" value="${proyectos.rowCount}"/>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Mi Proyecto de Grado - Estudiante SIGRADO UTS</title>
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

      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">
              Mi Proyecto de <span class="badge-title-box">GRADO</span>
            </h2>
            <div class="small text-muted mt-1">
              Consulta el estado de tu trabajo de grado, fases superadas y gestiona tus entregas oficiales
            </div>
          </div>
          <div>
            <c:if test="${total == 0}">
              <a href="${pageContext.request.contextPath}/estudiante/banco.jsp" class="btn btn-uts btn-sm">
                <i class="fas fa-plus me-1"></i> Inscribir Proyecto
              </a>
            </c:if>
          </div>
        </div>

        <div class="p-0">
          <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
              <thead class="table-light">
                <tr>
                  <th style="width: 14%;">Código</th>
                  <th style="width: 32%;">Título / Descripción</th>
                  <th style="width: 14%; text-align: center;">Fase / Turno</th>
                  <th style="width: 12%; text-align: center;">Estado</th>
                  <th style="width: 14%;">Director</th>
                  <th style="width: 14%; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
                <c:forEach var="p" items="${proyectos.rows}">
                  <tr>
                    <td class="fw-bold text-dark">${p.codigo}</td>
                    <td>
                      <div class="fw-semibold text-dark text-wrap">${p.titulo}</div>
                      <c:if test="${not empty p.descripcion}">
                        <div class="small text-muted text-wrap mt-1">
                          ${fn:substring(p.descripcion, 0, 90)}${fn:length(p.descripcion) > 90 ? '...' : ''}
                        </div>
                      </c:if>
                      <div class="small mt-1">
                        <span class="badge bg-light text-secondary border">${p.tipo_modalidad}</span>
                        <span class="badge bg-light text-secondary border">${p.tipo_nivel}</span>
                      </div>
                    </td>
                    <td style="text-align: center;">
                      <span class="badge-fase-dual activa-${p.responsable}">
                        <span class="fase-tag">Fase ${p.fase}</span>
                        <span class="actor-tag text-capitalize">${p.responsable}</span>
                      </span>
                    </td>
                    <td style="text-align: center;">
                      <c:choose>
                        <c:when test="${p.estado == 'Finalizado'}"><span class="badge-pill-custom badge-finalizado">Finalizado</span></c:when>
                        <c:when test="${p.estado == 'Rechazado' or p.estado == 'Rechazada'}"><span class="badge-pill-custom badge-rechazado">Rechazado</span></c:when>
                        <c:when test="${p.estado == 'Correcciones'}"><span class="badge bg-warning text-dark px-2 py-1">Correcciones</span></c:when>
                        <c:otherwise><span class="badge bg-primary px-2 py-1">${p.estado}</span></c:otherwise>
                      </c:choose>
                    </td>
                    <td>
                      <c:choose>
                        <c:when test="${not empty p.director}">
                          <div class="fw-semibold small text-dark">${p.director}</div>
                          <small class="text-muted">Docente Director</small>
                        </c:when>
                        <c:otherwise>
                          <small class="text-muted font-italic">En asignación por Comité</small>
                        </c:otherwise>
                      </c:choose>
                    </td>
                    <td style="text-align: center;">
                      <%-- 1. Seguimiento del proyecto --%>
                      <a href="${pageContext.request.contextPath}/estudiante/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Seguimiento cronológico de fases">
                        <i class="fas fa-sitemap"></i>
                      </a>

                      <%-- 2. Entregas y versiones --%>
                      <a href="${pageContext.request.contextPath}/estudiante/versiones.jsp?id=${p.id}" class="btn-icon-sq btn-icon-doc ms-1" title="Gestionar entregas y versiones">
                        <i class="fas fa-folder-open"></i>
                      </a>
                    </td>
                  </tr>
                </c:forEach>

                <c:if test="${total == 0}">
                  <tr>
                    <td colspan="6" class="text-center py-5 text-muted">
                      <i class="fas fa-folder-open fa-3x mb-3 text-secondary"></i>
                      <h6 class="fw-bold text-dark">No tienes proyectos de grado inscritos</h6>
                      <p class="small text-muted mb-3">
                        Puedes explorar el banco de ideas disponibles o proponer una idea propia.
                      </p>
                      <a href="${pageContext.request.contextPath}/estudiante/banco.jsp" class="btn btn-uts btn-sm">
                        <i class="fas fa-lightbulb me-1"></i> Ir al Banco de Ideas
                      </a>
                    </td>
                  </tr>
                </c:if>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>

    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>