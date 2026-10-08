<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ include file="/WEB-INF/jspf/guardDocente.jspf" %>

<%-- Codirector: solo consulta (sin responder). Lista proyectos donde es codirector. --%>
<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>
<c:set var="q" value="${param.q}"/>

<sql:query dataSource="${db}" var="conteo">
  SELECT COUNT(*) AS total FROM proyectos
  WHERE codirector_id = ? AND ('' = ? OR codigo LIKE ? OR titulo LIKE ?)
  <sql:param value="${sessionScope.usuario_id}"/>
  <sql:param value="${empty q ? '' : q}"/>
  <sql:param value="%${q}%"/>
  <sql:param value="%${q}%"/>
</sql:query>
<sql:query dataSource="${db}" var="proyectos">
  SELECT p.*, per.codigo AS periodo_codigo,
         CONCAT(d.nombres,' ',d.apellidos) AS director_nombre
  FROM proyectos p
  JOIN periodos per ON p.periodo_id = per.id
  LEFT JOIN usuarios d ON p.director_id = d.id
  WHERE p.codirector_id = ? AND ('' = ? OR p.codigo LIKE ? OR p.titulo LIKE ?)
  ORDER BY p.id DESC LIMIT ${limite} OFFSET ${offset}
  <sql:param value="${sessionScope.usuario_id}"/>
  <sql:param value="${empty q ? '' : q}"/>
  <sql:param value="%${q}%"/>
  <sql:param value="%${q}%"/>
</sql:query>
<c:set var="total" value="${conteo.rows[0].total}"/>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Codirector (Consulta) - SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>
    <div class="main-content">
      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">Codirector <span class="badge-title-box">CONSULTA</span></h2>
            <div class="small text-muted mt-1">Rol de solo consulta: puede ver entregas, versiones y seguimiento. No responde ni decide.</div>
          </div>
          <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver"><i class="fas fa-arrow-left"></i> Volver</a>
        </div>
        <div class="p-3">
          <form method="get" action="codirector.jsp" class="table-controls mb-3">
            <div class="d-flex align-items-center gap-2">
              <span class="small text-muted">Buscar:</span>
              <input type="text" name="q" class="form-control form-control-sm" style="width:250px" placeholder="Código o título..." value="${fn:escapeXml(q)}"/>
              <button type="submit" class="btn btn-uts btn-sm"><i class="fas fa-search"></i></button>
            </div>
          </form>
          <div class="table-responsive">
            <table class="table-sigrado">
              <thead><tr><th>Código</th><th>Título</th><th style="text-align:center">Fase Actual</th><th style="text-align:center">Estado</th><th>Director</th><th style="text-align:center">Acciones</th></tr></thead>
              <tbody>
                <c:choose>
                  <c:when test="${proyectos.rowCount > 0}">
                    <c:forEach items="${proyectos.rows}" var="p">
                      <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td>${p.titulo}</td>
                        <td style="text-align:center"><span class="badge-fase-dual activa-${p.responsable}"><span class="fase-tag">Fase ${p.fase}</span><span class="actor-tag text-capitalize">${p.responsable}</span></span></td>
                        <td style="text-align:center"><span class="badge bg-primary">${p.estado}</span></td>
                        <td class="small">${empty p.director_nombre ? 'Sin asignar' : p.director_nombre}</td>
                        <td style="text-align:center">
                          <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-eye" title="Ver entregas y versiones (ojo de cada fase)"><i class="fas fa-eye"></i></a>
                          <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Seguimiento de fases"><i class="fas fa-route"></i></a>
                        </td>
                      </tr>
                    </c:forEach>
                  </c:when>
                  <c:otherwise>
                    <tr><td colspan="6" class="text-center py-4 text-muted">No tienes proyectos asignados como codirector.</td></tr>
                  </c:otherwise>
                </c:choose>
              </tbody>
            </table>
          </div>
          <div class="small text-muted mt-2">Mostrando ${proyectos.rowCount} de ${total} proyectos.</div>
        </div>
      </div>
    </div>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>
