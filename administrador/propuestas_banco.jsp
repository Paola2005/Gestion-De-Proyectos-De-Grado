<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardAdministrador.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<c:if test="${param.accion == 'aprobar' and not empty param.id}">
  <c:catch var="err">
    <sql:update dataSource="${db}">
      UPDATE propuestas_banco SET estado='Aprobada', disponible=1, fecha_revision=NOW(), comite_revisor_id=?, observacion_comite=? WHERE id=?
      <sql:param value="${sessionScope.usuario_id}"/><sql:param value="${param.observacion}"/><sql:param value="${param.id}"/>
    </sql:update>
    <c:redirect url="/administrador/propuestas_banco.jsp"><c:param name="ok" value="Propuesta aprobada"/></c:redirect>
  </c:catch>
  <c:if test="${not empty err}"><c:redirect url="/administrador/propuestas_banco.jsp"><c:param name="error" value="Error al aprobar la propuesta. Intente de nuevo."/></c:redirect></c:if>
</c:if>

<c:if test="${param.accion == 'rechazar' and not empty param.id}">
  <c:catch var="err">
    <sql:update dataSource="${db}">
      UPDATE propuestas_banco SET estado='Rechazada', disponible=0, fecha_revision=NOW(), comite_revisor_id=?, observacion_comite=? WHERE id=?
      <sql:param value="${sessionScope.usuario_id}"/><sql:param value="${param.observacion}"/><sql:param value="${param.id}"/>
    </sql:update>
    <c:redirect url="/administrador/propuestas_banco.jsp"><c:param name="ok" value="Propuesta rechazada"/></c:redirect>
  </c:catch>
  <c:if test="${not empty err}"><c:redirect url="/administrador/propuestas_banco.jsp"><c:param name="error" value="Error al rechazar la propuesta. Intente de nuevo."/></c:redirect></c:if>
</c:if>

<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>
<c:set var="q" value="${param.q}"/>
<c:set var="filtroEstado" value="${param.filtroEstado}"/>

<sql:query dataSource="${db}" var="docentes">SELECT id, CONCAT(nombres,' ',apellidos) AS nombre FROM usuarios WHERE id IN (SELECT usuario_id FROM usuario_rol WHERE rol_id=3) ORDER BY nombres</sql:query>

<c:choose>
  <c:when test="${not empty q}">
    <sql:query dataSource="${db}" var="conteo">SELECT COUNT(*) AS total FROM propuestas_banco WHERE titulo LIKE CONCAT('%',?,'%') OR codigo LIKE CONCAT('%',?,'%')<sql:param value="${q}"/><sql:param value="${q}"/></sql:query>
    <sql:query dataSource="${db}" var="propuestas">
      SELECT pb.*, CONCAT(d.nombres,' ',d.apellidos) AS docente_nombre FROM propuestas_banco pb
      JOIN usuarios d ON pb.docente_id = d.id
      WHERE pb.titulo LIKE CONCAT('%',?,'%') OR pb.codigo LIKE CONCAT('%',?,'%')
      ORDER BY pb.fecha_propuesta DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${q}"/><sql:param value="${q}"/>
    </sql:query>
  </c:when>
  <c:when test="${not empty filtroEstado and filtroEstado!='TODOS'}">
    <sql:query dataSource="${db}" var="conteo">SELECT COUNT(*) AS total FROM propuestas_banco WHERE estado=?<sql:param value="${filtroEstado}"/></sql:query>
    <sql:query dataSource="${db}" var="propuestas">
      SELECT pb.*, CONCAT(d.nombres,' ',d.apellidos) AS docente_nombre FROM propuestas_banco pb
      JOIN usuarios d ON pb.docente_id = d.id
      WHERE pb.estado=? ORDER BY pb.fecha_propuesta DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${filtroEstado}"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteo">SELECT COUNT(*) AS total FROM propuestas_banco</sql:query>
    <sql:query dataSource="${db}" var="propuestas">
      SELECT pb.*, CONCAT(d.nombres,' ',d.apellidos) AS docente_nombre FROM propuestas_banco pb
      JOIN usuarios d ON pb.docente_id = d.id
      ORDER BY pb.fecha_propuesta DESC LIMIT ${limite} OFFSET ${offset}
    </sql:query>
  </c:otherwise>
</c:choose>
<c:set var="total" value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<!DOCTYPE html>
<html lang="es">
<head><title>Propuestas [BANCO] - Administrador SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
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

    <div class="card-sigrado">
      <div class="card-header-custom">
        <h2 class="page-title">
          Propuestas <span class="badge-title-box">BANCO</span>
        </h2>
        <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
          <i class="fas fa-arrow-left"></i> Volver
        </a>
      </div>
      <div class="p-3">
        <form method="get" action="propuestas_banco.jsp" class="table-controls mb-3">
          <div class="d-flex align-items-center gap-2">
            <span class="small text-muted">Buscar:</span>
            <input type="text" name="q" class="form-control form-control-sm" style="width: 220px;"
                   placeholder="Título o código BAN-" value="${fn:escapeXml(q)}">
            <select name="filtroEstado" class="form-select form-select-sm" style="width: 140px;">
              <option value="TODOS" ${filtroEstado=='TODOS'?'selected':''}>Todos</option>
              <option value="Pendiente" ${filtroEstado=='Pendiente'?'selected':''}>Pendiente</option>
              <option value="Aprobada" ${filtroEstado=='Aprobada'?'selected':''}>Aprobada</option>
              <option value="Rechazada" ${filtroEstado=='Rechazada'?'selected':''}>Rechazada</option>
            </select>
            <button type="submit" class="btn btn-uts btn-sm">Filtrar</button>
          </div>
        </form>

        <div class="table-responsive">
          <table class="table-sigrado">
            <thead>
              <tr>
                <th style="width: 120px;">Código</th>
                <th>Título</th>
                <th>Docente</th>
                <th>Modalidad</th>
                <th>Nivel</th>
                <th>Periodo</th>
                <th style="width: 120px; text-align: center;">Estado</th>
                <th style="width: 100px; text-align: center;">Disponible</th>
                <th style="width: 120px; text-align: center;">Acciones</th>
              </tr>
            </thead>
            <tbody>
              <c:forEach items="${propuestas.rows}" var="p">
                <tr>
                  <td class="fw-bold">${p.codigo}</td>
                  <td>${p.titulo}<br><small class="text-muted">${fn:substring(p.objetivo_general,0,80)}...</small></td>
                  <td>${p.docente_nombre}</td>
                  <td><span class="badge bg-info text-white">${p.tipo_modalidad}</span></td>
                  <td><span class="badge bg-secondary">${p.tipo_nivel}</span></td>
                  <td>${p.periodo_id}</td>
                  <td style="text-align: center;">
                    <span class="badge ${p.estado=='Aprobada'?'bg-success':p.estado=='Rechazada'?'bg-danger':'bg-warning text-dark'}">${p.estado}</span>
                  </td>
                  <td style="text-align: center;">
                    <c:choose>
                      <c:when test="${p.disponible}"><span class="badge bg-success">Sí</span></c:when>
                      <c:otherwise><span class="badge bg-secondary">No</span></c:otherwise>
                    </c:choose>
                  </td>
                  <td style="text-align: center;">
                    <button class="btn-action btn-ver" data-bs-toggle="modal" data-bs-target="#detalle${p.id}" title="Ver detalles"><i class="fas fa-eye"></i></button>
                    <c:if test="${p.estado=='Pendiente'}">
                      <button class="btn-action btn-seguimiento ms-1" data-bs-toggle="modal" data-bs-target="#aprobar${p.id}" title="Aprobar"><i class="fas fa-check"></i></button>
                      <button class="btn-action btn-retirar ms-1" data-bs-toggle="modal" data-bs-target="#rechazar${p.id}" title="Rechazar"><i class="fas fa-times"></i></button>
                    </c:if>
                  </td>
                </tr>

                <div class="modal fade" id="detalle${p.id}" tabindex="-1">
                  <div class="modal-dialog modal-lg"><div class="modal-content">
                    <div class="modal-header modal-header-sigrado"><h5 class="modal-title">${p.codigo} - ${p.titulo}</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
                    <div class="modal-body row g-3">
                      <div class="col-md-6"><strong>Docente:</strong> ${p.docente_nombre}</div>
                      <div class="col-md-6"><strong>Modalidad:</strong> ${p.tipo_modalidad}</div>
                      <div class="col-md-6"><strong>Nivel:</strong> ${p.tipo_nivel}</div>
                      <div class="col-md-6"><strong>Periodo:</strong> ${p.periodo_id}</div>
                      <div class="col-md-6"><strong>Estado:</strong> <span class="badge ${p.estado=='Aprobada'?'bg-success':p.estado=='Rechazada'?'bg-danger':'bg-warning text-dark'}">${p.estado}</span></div>
                      <div class="col-md-6"><strong>Disponible:</strong> ${p.disponible?'Sí':'No'}</div>
                      <div class="col-12"><strong>Objetivo General:</strong><p>${p.objetivo_general}</p></div>
                      <div class="col-12"><strong>Línea de Investigación:</strong> ${p.linea_investigacion}</div>
                      <c:if test="${not empty p.observacion_comite}"><div class="col-12"><strong>Observación:</strong> ${p.observacion_comite}</div></c:if>
                      <div class="col-12"><small class="text-muted">Propuesta: ${fn:substring(p.fecha_propuesta,0,19)} | Revisión: ${p.fecha_revision!=null?fn:substring(p.fecha_revision,0,19):'—'}</small></div>
                    </div>
                    <div class="modal-footer"><button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cerrar</button></div>
                  </div></div>
                </div>

                <div class="modal fade" id="aprobar${p.id}" tabindex="-1">
                  <div class="modal-dialog"><form method="post" class="modal-content">
                    <input type="hidden" name="accion" value="aprobar"/><input type="hidden" name="id" value="${p.id}"/>
                    <div class="modal-header modal-header-sigrado"><h5 class="modal-title">Aprobar ${p.codigo}</h5><button type="button" class="btn-close" data-bs-dismiss="modal"></button></div>
                    <div class="modal-body">
                      <div class="mb-3"><label class="form-label">N° Acta *</label><input type="text" name="acta" class="form-control" required placeholder="ACTA-2026-XXX"></div>
                      <div class="mb-3"><label class="form-label">Observación (opcional)</label><textarea name="observacion" class="form-control" rows="2" placeholder="Comentarios de aprobación..."></textarea></div>
                    </div>
                    <div class="modal-footer"><button type="submit" class="btn btn-uts">Confirmar Aprobación</button></form></div>
                  </div>
                </div>

                <div class="modal fade" id="rechazar${p.id}" tabindex="-1">
                  <div class="modal-dialog"><form method="post" class="modal-content">
                    <input type="hidden" name="accion" value="rechazar"/><input type="hidden" name="id" value="${p.id}"/>
                    <div class="modal-header bg-danger"><h5 class="modal-title">Rechazar ${p.codigo}</h5><button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button></div>
                    <div class="modal-body">
                      <div class="mb-3"><label class="form-label">N° Acta *</label><input type="text" name="acta" class="form-control" required placeholder="ACTA-2026-XXX"></div>
                      <div class="mb-3"><label class="form-label">Motivo *</label><textarea name="observacion" class="form-control" rows="3" required placeholder="Explique el motivo del rechazo..."></textarea></div>
                    </div>
                    <div class="modal-footer"><button type="submit" class="btn btn-danger">Confirmar Rechazo</button></form></div>
                  </div>
                </div>
              </c:forEach>
              <c:if test="${propuestas.rowCount==0}"><tr><td colspan="9" class="empty-state">No hay propuestas registradas</td></tr></c:if>
            </tbody>
          </table>
        </div>

        <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap">
          <div class="small text-muted">Mostrando página ${pagina} de ${totalPaginas} (${total} registros)</div>
          <nav><ul class="pagination pagination-sm mb-0"><c:forEach begin="1" end="${totalPaginas}" var="i"><li class="page-item ${i==pagina?'active':''}"><a class="page-link" href="propuestas_banco.jsp?pagina=${i}&limite=${limite}&q=${fn:escapeXml(q)}&filtroEstado=${filtroEstado}">${i}</a></li></c:forEach></ul></nav>
        </div>
      </div>
    </div>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</div>
</body>
</html>