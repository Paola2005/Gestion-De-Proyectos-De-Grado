<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardDocente.jspf" %>

<c:if test="${param.accion == 'crear'}">
  <c:catch var="err">
    <c:if test="${empty param.titulo or empty param.objetivo or empty param.linea or empty param.modalidad or empty param.nivel or empty param.periodo_id}">
      <c:redirect url="/docente/propuestas_banco.jsp"><c:param name="error" value="Todos los campos son obligatorios"/></c:redirect>
    </c:if>
    <sql:transaction dataSource="${db}">
      <sql:query var="maxId">SELECT COALESCE(MAX(id),0)+1 AS nid FROM propuestas_banco</sql:query>
      <c:set var="nuevoCodigo" value="BAN-${fn:substring('00000',0,5 - fn:length(maxId.rows[0].nid))}${maxId.rows[0].nid}"/>
      <sql:update>
        INSERT INTO propuestas_banco (codigo,docente_id,titulo,tipo_modalidad,objetivo_general,linea_investigacion,tipo_nivel,periodo_id,estado,disponible)
        VALUES (?,?,?,?,?,?,?,?,'Pendiente',1)
        <sql:param value="${nuevoCodigo}"/><sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.titulo}"/><sql:param value="${param.modalidad}"/>
        <sql:param value="${param.objetivo}"/><sql:param value="${param.linea}"/>
        <sql:param value="${param.nivel}"/><sql:param value="${param.periodo_id}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/docente/propuestas_banco.jsp"><c:param name="ok" value="Propuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty err}"><c:redirect url="/docente/propuestas_banco.jsp"><c:param name="error" value="No se pudo enviar la propuesta. Intente de nuevo."/></c:redirect></c:if>
</c:if>

<sql:query dataSource="${db}" var="periodos">SELECT id, codigo FROM periodos WHERE activo=1 ORDER BY id DESC</sql:query>

<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>

<sql:query dataSource="${db}" var="conteo">SELECT COUNT(*) AS total FROM propuestas_banco WHERE docente_id=?<sql:param value="${sessionScope.usuario_id}"/></sql:query>
<sql:query dataSource="${db}" var="misPropuestas">
  SELECT pb.* FROM propuestas_banco pb WHERE pb.docente_id=? ORDER BY pb.fecha_propuesta DESC LIMIT ${limite} OFFSET ${offset}
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>
<c:set var="total" value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<!DOCTYPE html>
<html lang="es">
<head><title>Mis Propuestas [BANCO] - SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
<body>
<%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
<main class="main">
  <header class="topbar">
    <div class="welcome">Mis Propuestas <span class="text-uts">[BANCO]</span></div>
    <div class="user-info"><div class="user-name">${sessionScope.usuario_nombres} ${sessionScope.usuario_apellidos}</div><div class="user-rol">${sessionScope.rol_principal}</div></div>
  </header>
  <div class="container-fluid py-4 px-4">
    <div class="row g-4">
      <div class="col-12">
        <div class="card-uts mb-4">
          <div class="card-header-uts"><h5 class="card-title-institucional mb-0">Nueva Propuesta al Banco</h5></div>
          <div class="card-body">
            <form method="post" class="row g-3" action="propuestas_banco.jsp">
              <input type="hidden" name="accion" value="crear"/>
              <div class="col-md-6"><label class="form-label">Título *</label><input type="text" name="titulo" class="form-control" required placeholder="Título de la idea"></div>
              <div class="col-md-3"><label class="form-label">Modalidad *</label><select name="modalidad" class="form-select" required><option value="">Seleccione</option><option value="Desarrollo tecnologico">Desarrollo tecnológico</option><option value="Emprendimiento">Emprendimiento</option><option value="Investigacion">Investigación</option><option value="Otro">Otro</option></select></div>
              <div class="col-md-3"><label class="form-label">Nivel *</label><select name="nivel" class="form-select" required><option value="">Seleccione</option><option value="Tecnologico">Tecnológico</option><option value="Profesional">Profesional</option></select></div>
              <div class="col-md-3"><label class="form-label">Periodo *</label><select name="periodo_id" class="form-select" required><c:forEach items="${periodos.rows}" var="p"><option value="${p.id}">${p.codigo}</option></c:forEach></select></div>
              <div class="col-12"><label class="form-label">Objetivo General *</label><textarea name="objetivo" class="form-control" rows="3" required placeholder="Describa el objetivo general..."></textarea></div>
              <div class="col-12"><label class="form-label">Línea de Investigación *</label><input type="text" name="linea" class="form-control" required placeholder="Ej: Ingeniería de Software, Inteligencia Artificial..."></div>
              <div class="col-12"><button type="submit" class="btn btn-uts">Enviar Propuesta</button></div>
            </form>
          </div>
        </div>
      </div>
      <div class="col-12">
        <div class="card-uts">
          <div class="card-header-uts"><h5 class="card-title-institucional mb-0">Mis Propuestas Enviadas</h5></div>
          <div class="card-body p-0">
            <div class="table-responsive">
              <table class="table table-hover mb-0">
                <thead><tr><th>Código</th><th>Título</th><th>Modalidad</th><th>Nivel</th><th>Estado</th><th>Disponible</th><th>Fecha</th><th>Acciones</th></tr></thead>
                <tbody>
                  <c:forEach items="${misPropuestas.rows}" var="p">
                    <tr>
                      <td><strong>${p.codigo}</strong></td>
                      <td>${p.titulo}</td>
                      <td><span class="badge bg-info text-white">${p.tipo_modalidad}</span></td>
                      <td><span class="badge bg-secondary">${p.tipo_nivel}</span></td>
                      <td><span class="badge ${p.estado=='Aprobada'?'bg-success':p.estado=='Rechazada'?'bg-danger':'bg-warning text-dark'}">${p.estado}</span></td>
                      <td>
                        <c:choose>
                          <c:when test="${p.disponible}"><span class="badge bg-success">Sí</span></c:when>
                          <c:otherwise><span class="badge bg-secondary">No</span></c:otherwise>
                        </c:choose>
                      </td>
                      <td><small>${fn:substring(p.fecha_propuesta,0,16)}</small></td>
                      <td>
                        <button class="btn-action btn-ver" data-bs-toggle="modal" data-bs-target="#detalle${p.id}"><i class="fas fa-eye"></i></button>
                      </td>
                    </tr>
                    <div class="modal fade" id="detalle${p.id}" tabindex="-1">
                      <div class="modal-dialog modal-lg"><div class="modal-content">
                        <div class="modal-header bg-uts"><h5 class="modal-title">${p.codigo} - ${p.titulo}</h5><button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button></div>
                        <div class="modal-body row g-3">
                          <div class="col-md-6"><strong>Modalidad:</strong> ${p.tipo_modalidad}</div>
                          <div class="col-md-6"><strong>Nivel:</strong> ${p.tipo_nivel}</div>
                          <div class="col-md-6"><strong>Periodo:</strong> ${p.periodo_id}</div>
                          <div class="col-md-6"><strong>Estado:</strong> <span class="badge ${p.estado=='Aprobada'?'bg-success':p.estado=='Rechazada'?'bg-danger':'bg-warning text-dark'}">${p.estado}</span></div>
                          <div class="col-md-6"><strong>Disponible:</strong>
                            <c:choose>
                              <c:when test="${p.disponible}">Sí</c:when>
                              <c:otherwise>No</c:otherwise>
                            </c:choose>
                          </div>
                          <div class="col-12"><strong>Objetivo:</strong><p>${p.objetivo_general}</p></div>
                          <div class="col-12"><strong>Línea:</strong> ${p.linea_investigacion}</div>
                          <c:if test="${not empty p.observacion_comite}"><div class="col-12"><strong>Obs. Comité:</strong> ${p.observacion_comite}</div></c:if>
                          <div class="col-12"><small class="text-muted">Enviado: ${fn:substring(p.fecha_propuesta,0,19)}</small></div>
                        </div>
                        <div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cerrar</button></div>
                      </div></div>
                    </div>
                  </c:forEach>
                  <c:if test="${misPropuestas.rowCount==0}"><tr><td colspan="8" class="empty-state">No ha enviado propuestas aún</td></tr></c:if>
                </tbody>
              </table>
            </div>
            <div class="card-body border-top"><nav><ul class="pagination pagination-sm mb-0 justify-content-center"><c:forEach begin="1" end="${totalPaginas}" var="i"><li class="page-item ${i==pagina?'active':''}"><a class="page-link" href="propuestas_banco.jsp?pagina=${i}&limite=${limite}">${i}</a></li></c:forEach></ul></nav></div>
          </div>
        </div>
      </div>
    </div>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</main>
</body>
</html>

