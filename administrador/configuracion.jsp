<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardAdministrador.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<c:if test="${param.accion == 'backup'}">
  <c:catch var="errBk">
    <sql:query dataSource="${db}" var="bkCount">
      SELECT (SELECT COUNT(*) FROM usuarios) AS u, (SELECT COUNT(*) FROM proyectos) AS p,
             (SELECT COUNT(*) FROM propuestas_banco) AS b, (SELECT COUNT(*) FROM documentos) AS d
    </sql:query>
    <c:redirect url="/administrador/configuracion.jsp">
      <c:param name="ok" value="Respaldo verificado: ${bkCount.rows[0].u} usuarios, ${bkCount.rows[0].p} proyectos, ${bkCount.rows[0].b} ideas, ${bkCount.rows[0].d} documentos. Para descargar el .sql use phpMyAdmin > Exportar (sin servlets no se genera el archivo desde JSP)."/>
    </c:redirect>
  </c:catch>
  <c:if test="${not empty errBk}">
    <c:redirect url="/administrador/configuracion.jsp"><c:param name="error" value="No se pudo verificar el respaldo. Intente de nuevo."/></c:redirect>
  </c:if>
</c:if>

<%-- Crear periodo con sus fechas (preparación del flujo) --%>
<c:if test="${param.accion == 'crear_periodo'}">
  <c:catch var="errPer">
    <c:if test="${empty param.codigo or empty param.ini_banco or empty param.fin_banco or empty param.ini_proy or empty param.fin_aprob}">
      <c:redirect url="/administrador/configuracion.jsp"><c:param name="error" value="Todos los campos del periodo (código y 4 fechas) son obligatorios."/></c:redirect>
    </c:if>
    <sql:update dataSource="${db}">
      INSERT INTO periodos (codigo, inicio_propuestas_banco, fin_propuestas_banco, inicio_nuevos_proyectos, fin_aprobacion_propuesta, activo)
      VALUES (?, ?, ?, ?, ?, 0)
      <sql:param value="${param.codigo}"/>
      <sql:param value="${param.ini_banco}"/>
      <sql:param value="${param.fin_banco}"/>
      <sql:param value="${param.ini_proy}"/>
      <sql:param value="${param.fin_aprob}"/>
    </sql:update>
    <c:redirect url="/administrador/configuracion.jsp"><c:param name="ok" value="Periodo creado correctamente. Actívelo cuando inicie."/></c:redirect>
  </c:catch>
  <c:if test="${not empty errPer}">
    <c:redirect url="/administrador/configuracion.jsp"><c:param name="error" value="No se pudo crear el periodo (¿código duplicado o fechas inválidas?)."/></c:redirect>
  </c:if>
</c:if>

<%-- Activar un periodo (solo uno activo a la vez) --%>
<c:if test="${param.accion == 'activar_periodo' and not empty param.id}">
  <c:catch var="errAct">
    <sql:transaction dataSource="${db}">
      <sql:update>UPDATE periodos SET activo = 0</sql:update>
      <sql:update>UPDATE periodos SET activo = 1 WHERE id = ?<sql:param value="${param.id}"/></sql:update>
    </sql:transaction>
    <c:redirect url="/administrador/configuracion.jsp"><c:param name="ok" value="Periodo activado correctamente."/></c:redirect>
  </c:catch>
  <c:if test="${not empty errAct}">
    <c:redirect url="/administrador/configuracion.jsp"><c:param name="error" value="No se pudo activar el periodo."/></c:redirect>
  </c:if>
</c:if>

<sql:query dataSource="${db}" var="periodoActivo">
  SELECT * FROM periodos WHERE activo=1 LIMIT 1
</sql:query>

<sql:query dataSource="${db}" var="periodos">
  SELECT * FROM periodos ORDER BY id DESC
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Configuración - Administrador · SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-check-circle me-1"></i> <c:out value="${param.ok}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty param.error}">
        <div class="alert alert-danger alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-exclamation-triangle me-1"></i> <c:out value="${param.error}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <div class="row g-4">
        <%-- Generar copia de seguridad --%>
        <div class="col-lg-6">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <h2 class="page-title">
                Copia de <span class="badge-title-box">SEGURIDAD</span>
              </h2>
            </div>
            <div class="p-4">
              <div class="alert alert-info small">
                <i class="fas fa-info-circle me-1"></i>
                Verifica el contenido actual y orienta la descarga del .sql desde phpMyAdmin (las reglas fijas no permiten servlets ni scriptlets para generar el archivo).
              </div>
              <form method="post" action="configuracion.jsp">
                <input type="hidden" name="accion" value="backup"/>
                <div class="d-flex gap-2">
                  <button type="submit" class="btn btn-uts">
                    <i class="fas fa-download me-1"></i> Verificar respaldo
                  </button>
                </div>
              </form>
              <hr class="my-3">
              <h6 class="fw-bold">Periodos Académicos</h6>
              <p class="small text-muted">Solo puede haber un periodo activo a la vez. Las acciones del sistema respetan estas fechas.</p>
              <form method="post" action="configuracion.jsp" class="row g-2 mb-3">
                <input type="hidden" name="accion" value="crear_periodo"/>
                <div class="col-md-4">
                  <label class="form-label small fw-bold">Código *</label>
                  <input type="text" name="codigo" class="form-control form-control-sm" required placeholder="ej: 2027-1"/>
                </div>
                <div class="col-md-4">
                  <label class="form-label small fw-bold">Inicio propuestas banco *</label>
                  <input type="date" name="ini_banco" class="form-control form-control-sm" required/>
                </div>
                <div class="col-md-4">
                  <label class="form-label small fw-bold">Fin propuestas banco *</label>
                  <input type="date" name="fin_banco" class="form-control form-control-sm" required/>
                </div>
                <div class="col-md-4">
                  <label class="form-label small fw-bold">Inicio nuevos proyectos *</label>
                  <input type="date" name="ini_proy" class="form-control form-control-sm" required/>
                </div>
                <div class="col-md-4">
                  <label class="form-label small fw-bold">Fin aprobación propuesta *</label>
                  <input type="date" name="fin_aprob" class="form-control form-control-sm" required/>
                </div>
                <div class="col-md-4 d-flex align-items-end">
                  <button type="submit" class="btn btn-uts btn-sm w-100"><i class="fas fa-plus me-1"></i>Crear periodo</button>
                </div>
              </form>
              <div class="table-responsive">
                <table class="table table-sm table-hover">
                  <thead><tr><th>Código</th><th>Inicio Banco</th><th>Fin Banco</th><th>Inicio Proyectos</th><th>Fin Aprobación</th><th>Activo</th><th></th></tr></thead>
                  <tbody>
                    <c:forEach var="p" items="${periodos.rows}">
                      <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td><fmt:formatDate value="${p.inicio_propuestas_banco}" pattern="dd/MM/yyyy"/></td>
                        <td><fmt:formatDate value="${p.fin_propuestas_banco}" pattern="dd/MM/yyyy"/></td>
                        <td><fmt:formatDate value="${p.inicio_nuevos_proyectos}" pattern="dd/MM/yyyy"/></td>
                        <td><fmt:formatDate value="${p.fin_aprobacion_propuesta}" pattern="dd/MM/yyyy"/></td>
                        <td>
                          <c:choose>
                            <c:when test="${p.activo}"><span class="badge bg-success">Activo</span></c:when>
                            <c:otherwise><span class="badge bg-secondary">Inactivo</span></c:otherwise>
                          </c:choose>
                        </td>
                        <td>
                          <c:if test="${not p.activo}">
                            <form method="post" action="configuracion.jsp" class="d-inline">
                              <input type="hidden" name="accion" value="activar_periodo"/>
                              <input type="hidden" name="id" value="${p.id}"/>
                              <button type="submit" class="btn btn-outline-success btn-sm" title="Activar periodo">Activar</button>
                            </form>
                          </c:if>
                        </td>
                      </tr>
                    </c:forEach>
                  </tbody>
                </table>
              </div>
            </div>
          </div>
        </div>

        <%-- Información del sistema --%>
        <div class="col-lg-6">
          <div class="card-sigrado h-100">
            <div class="card-header-custom">
              <h2 class="page-title">
                Información del <span class="badge-title-box">SISTEMA</span>
              </h2>
            </div>
            <div class="p-4">
              <div class="row g-3">
                <div class="col-6">
                  <div class="p-3 bg-light rounded border">
                    <div class="small text-muted">Versión</div>
                    <div class="fw-bold">SIGRADO 2.0</div>
                  </div>
                </div>
                <div class="col-6">
                  <div class="p-3 bg-light rounded border">
                    <div class="small text-muted">Motor BD</div>
                    <div class="fw-bold">MySQL 8.0+</div>
                  </div>
                </div>
                <div class="col-6">
                  <div class="p-3 bg-light rounded border">
                    <div class="small text-muted">Codificación</div>
                    <div class="fw-bold">UTF-8 (utf8mb4)</div>
                  </div>
                </div>
                <div class="col-6">
                  <div class="p-3 bg-light rounded border">
                    <div class="small text-muted">Framework</div>
                    <div class="fw-bold">JSP + JSTL + EL</div>
                  </div>
                </div>
              </div>
              <hr class="my-3">
              <h6 class="fw-bold">Enlaces rápidos</h6>
              <div class="d-flex flex-wrap gap-2">
                <a href="${pageContext.request.contextPath}/administrador/formatos.jsp" class="btn btn-outline-primary btn-sm">Gestionar Formatos</a>
                <a href="${pageContext.request.contextPath}/administrador/proyectos.jsp" class="btn btn-outline-secondary btn-sm">Ver Proyectos</a>
                <a href="${pageContext.request.contextPath}/administrador/banco.jsp" class="btn btn-outline-secondary btn-sm">Banco de Ideas</a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>