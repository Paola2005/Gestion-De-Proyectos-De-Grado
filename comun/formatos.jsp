<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%-- comun/formatos.jsp - Base documental: formatos cargados por el administrador (tabla formatos) + enlaces institucionales --%>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>
<sql:query dataSource="${db}" var="formatosAct">
  SELECT codigo, nombre, url FROM formatos WHERE activo = 1 ORDER BY codigo
</sql:query>
<!DOCTYPE html>
<html lang="es">
<head><title>Base documental - SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
<body>
<%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
<div class="main-wrapper">
  <%@ include file="/WEB-INF/jspf/topbar.jspf" %>
  <div class="main-content">
    <div class="card-sigrado p-4">
      <h2 class="page-title">Base <span class="badge-title-box">DOCUMENTAL</span></h2>
      <p class="text-muted small mb-4">Formatos institucionales vigentes cargados por el administrador, más enlaces oficiales UTS.</p>
      <div class="row g-3">
        <c:forEach var="f" items="${formatosAct.rows}">
          <div class="col-md-4">
            <a href="${f.url}" target="_blank" rel="noopener noreferrer" class="text-decoration-none">
              <div class="card-sigrado p-3 h-100 text-center">
                <div class="fw-bold text-dark">${f.codigo}</div>
                <div class="small text-muted mt-1">${f.nombre}</div>
                <span class="btn btn-outline-primary btn-sm mt-2"><i class="fas fa-download me-1"></i> Descargar plantilla</span>
              </div>
            </a>
          </div>
        </c:forEach>
        <c:if test="${formatosAct.rowCount == 0}">
          <div class="col-12"><div class="alert alert-warning small mb-0">No hay formatos activos cargados. Contacte al administrador.</div></div>
        </c:if>
        <div class="col-md-4">
          <a href="https://www.uts.edu.co/sitio/calendario-academico/" target="_blank" rel="noopener noreferrer" class="text-decoration-none">
            <div class="card-sigrado p-3 h-100 text-center">
              <div class="fw-bold text-dark">Calendario Académico</div>
              <div class="small text-muted mt-1">Fechas oficiales UTS</div>
            </div>
          </a>
        </div>
        <div class="col-md-4">
          <a href="https://www.uts.edu.co/sitio/normatividad/" target="_blank" rel="noopener noreferrer" class="text-decoration-none">
            <div class="card-sigrado p-3 h-100 text-center">
              <div class="fw-bold text-dark">Normatividad TG</div>
              <div class="small text-muted mt-1">Reglamento de trabajos de grado</div>
            </div>
          </a>
        </div>
      </div>
    </div>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</div>
</body>
</html>
