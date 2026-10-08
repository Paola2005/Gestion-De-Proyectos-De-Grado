<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardAdministrador.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<%-- ============================================================
     ACCIÓN: Cancelar proyecto
     ============================================================ --%>
<c:if test="${param.accion == 'cancelar' and not empty param.proyecto_id}">
  <c:catch var="errCancel">
    <sql:transaction dataSource="${db}">
      <sql:update>
        UPDATE proyectos SET estado='Cancelado', fecha_actualizacion=NOW()
        WHERE id=? AND estado='En curso'
        <sql:param value="${param.proyecto_id}"/>
      </sql:update>
      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
        SELECT id, ?, 'Cancelación por Administrador', fase, ?
        FROM proyectos WHERE id=?
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${empty param.motivo ? 'Sin motivo especificado' : param.motivo}"/>
        <sql:param value="${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
  </c:catch>
  <c:choose>
    <c:when test="${not empty errCancel}">
      <c:redirect url="/administrador/proyectos.jsp"><c:param name="error" value="Error al cancelar el proyecto."/></c:redirect>
    </c:when>
    <c:otherwise>
      <c:redirect url="/administrador/proyectos.jsp"><c:param name="ok" value="Proyecto cancelado correctamente."/></c:redirect>
    </c:otherwise>
  </c:choose>
</c:if>

<%-- ============================================================
     ACCIÓN: Reasignar tribunal
     ============================================================ --%>
<c:if test="${param.accion == 'reasignar' and not empty param.proyecto_id}">
  <c:if test="${not empty param.nuevo_director_id and not empty param.nuevo_evaluador_id and param.nuevo_director_id == param.nuevo_evaluador_id}">
    <c:redirect url="/administrador/proyectos.jsp"><c:param name="error" value="El director y el evaluador deben ser docentes diferentes."/></c:redirect>
  </c:if>
  <c:catch var="errReasignar">
    <sql:transaction dataSource="${db}">
      <sql:update>
        UPDATE proyectos
        SET director_id   = CASE WHEN ? = '' OR ? IS NULL THEN director_id   ELSE ? END,
            evaluador_id  = CASE WHEN ? = '' OR ? IS NULL THEN evaluador_id  ELSE ? END,
            codirector_id = NULL,
            fecha_actualizacion = NOW()
        WHERE id = ?
        <sql:param value="${param.nuevo_director_id}"/><sql:param value="${param.nuevo_director_id}"/><sql:param value="${param.nuevo_director_id}"/>
        <sql:param value="${param.nuevo_evaluador_id}"/><sql:param value="${param.nuevo_evaluador_id}"/><sql:param value="${param.nuevo_evaluador_id}"/>
        <sql:param value="${param.proyecto_id}"/>
      </sql:update>
      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, comentario)
        SELECT id, ?, 'Reasignación de Tribunal', fase, 'Reasignación realizada por el Administrador'
        FROM proyectos WHERE id=?
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
  </c:catch>
  <c:choose>
    <c:when test="${not empty errReasignar}">
      <c:redirect url="/administrador/proyectos.jsp"><c:param name="error" value="Error al reasignar tribunal."/></c:redirect>
    </c:when>
    <c:otherwise>
      <c:redirect url="/administrador/proyectos.jsp"><c:param name="ok" value="Tribunal reasignado correctamente."/></c:redirect>
    </c:otherwise>
  </c:choose>
</c:if>

<%-- ============================================================
     CONSULTAR DATOS
     ============================================================ --%>
<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>
<c:set var="q"      value="${param.q}"/>
<c:set var="filtroFase"   value="${param.fase}"/>
<c:set var="filtroEstado" value="${param.estado}"/>

<c:catch var="errQuery">
  <c:choose>
    <c:when test="${not empty q}">
      <sql:query dataSource="${db}" var="conteo">
        SELECT COUNT(*) AS total
        FROM proyectos p
        JOIN proyecto_integrantes pi ON pi.proyecto_id=p.id AND pi.es_responsable=1
        JOIN usuarios e ON pi.usuario_id=e.id
        WHERE (p.codigo LIKE CONCAT('%',?,'%')
               OR p.titulo LIKE CONCAT('%',?,'%')
               OR e.nombres LIKE CONCAT('%',?,'%')
               OR e.apellidos LIKE CONCAT('%',?,'%')
               OR e.documento LIKE CONCAT('%',?,'%'))
          AND (? = '' OR p.fase = ?)
          AND (? = '' OR p.estado = ?)
        <sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/>
        <sql:param value="${q}"/><sql:param value="${q}"/>
        <sql:param value="${filtroFase}"/><sql:param value="${filtroFase}"/>
        <sql:param value="${filtroEstado}"/><sql:param value="${filtroEstado}"/>
      </sql:query>
      <sql:query dataSource="${db}" var="proyectos">
        SELECT p.*,
          GROUP_CONCAT(DISTINCT CONCAT(u2.nombres,' ',u2.apellidos,' (',u2.documento,')') SEPARATOR ' | ') AS estudiantes_info,
          CONCAT(d.nombres,' ',d.apellidos)  AS director_nombre,
          CONCAT(ev.nombres,' ',ev.apellidos) AS evaluador_nombre,
          CONCAT(cd.nombres,' ',cd.apellidos) AS codirector_nombre
        FROM proyectos p
        JOIN proyecto_integrantes pi ON pi.proyecto_id=p.id
        JOIN usuarios u2 ON pi.usuario_id=u2.id
        JOIN proyecto_integrantes pir ON pir.proyecto_id=p.id AND pir.es_responsable=1
        JOIN usuarios e ON pir.usuario_id=e.id
        LEFT JOIN usuarios d  ON p.director_id=d.id
        LEFT JOIN usuarios ev ON p.evaluador_id=ev.id
        LEFT JOIN usuarios cd ON p.codirector_id=cd.id
        WHERE (p.codigo LIKE CONCAT('%',?,'%')
               OR p.titulo LIKE CONCAT('%',?,'%')
               OR e.nombres LIKE CONCAT('%',?,'%')
               OR e.apellidos LIKE CONCAT('%',?,'%')
               OR e.documento LIKE CONCAT('%',?,'%'))
          AND (? = '' OR p.fase = ?)
          AND (? = '' OR p.estado = ?)
        GROUP BY p.id
        ORDER BY p.fecha_creacion DESC
        LIMIT ${limite} OFFSET ${offset}
        <sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/>
        <sql:param value="${q}"/><sql:param value="${q}"/>
        <sql:param value="${filtroFase}"/><sql:param value="${filtroFase}"/>
        <sql:param value="${filtroEstado}"/><sql:param value="${filtroEstado}"/>
      </sql:query>
    </c:when>
    <c:otherwise>
      <sql:query dataSource="${db}" var="conteo">
        SELECT COUNT(*) AS total FROM proyectos p
        WHERE (? = '' OR p.fase = ?)
          AND (? = '' OR p.estado = ?)
        <sql:param value="${filtroFase}"/><sql:param value="${filtroFase}"/>
        <sql:param value="${filtroEstado}"/><sql:param value="${filtroEstado}"/>
      </sql:query>
      <sql:query dataSource="${db}" var="proyectos">
        SELECT p.*,
          GROUP_CONCAT(DISTINCT CONCAT(u2.nombres,' ',u2.apellidos,' (',u2.documento,')') SEPARATOR ' | ') AS estudiantes_info,
          CONCAT(d.nombres,' ',d.apellidos)  AS director_nombre,
          CONCAT(ev.nombres,' ',ev.apellidos) AS evaluador_nombre,
          CONCAT(cd.nombres,' ',cd.apellidos) AS codirector_nombre
        FROM proyectos p
        JOIN proyecto_integrantes pi ON pi.proyecto_id=p.id
        JOIN usuarios u2 ON pi.usuario_id=u2.id
        LEFT JOIN usuarios d  ON p.director_id=d.id
        LEFT JOIN usuarios ev ON p.evaluador_id=ev.id
        LEFT JOIN usuarios cd ON p.codirector_id=cd.id
        WHERE (? = '' OR p.fase = ?)
          AND (? = '' OR p.estado = ?)
        GROUP BY p.id
        ORDER BY p.fecha_creacion DESC
        LIMIT ${limite} OFFSET ${offset}
        <sql:param value="${filtroFase}"/><sql:param value="${filtroFase}"/>
        <sql:param value="${filtroEstado}"/><sql:param value="${filtroEstado}"/>
      </sql:query>
    </c:otherwise>
  </c:choose>
</c:catch>

<c:set var="total"       value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<%-- Lista de docentes para reasignar --%>
<sql:query dataSource="${db}" var="docentesList">
  SELECT u.id, CONCAT(u.nombres,' ',u.apellidos) AS nombre
  FROM usuarios u
  JOIN usuario_rol ur ON ur.usuario_id=u.id
  JOIN roles r ON r.id=ur.rol_id AND r.nombre='docente'
  WHERE u.activo=1
  ORDER BY u.apellidos, u.nombres
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Proyectos de Grado · Administrador · SIGRADO</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>
    <div class="main-content">

      <%-- Alertas --%>
      <c:if test="${not empty param.error}">
        <div class="alert alert-danger alert-dismissible fade show">
          <i class="fas fa-exclamation-circle me-2"></i><c:out value="${param.error}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show">
          <i class="fas fa-check-circle me-2"></i><c:out value="${param.ok}"/>
          <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <div class="card-sigrado">
        <div class="card-header-custom">
          <h2 class="page-title">Proyectos de <span class="badge-title-box">GRADO</span></h2>
          <span class="badge badge-uts">${total} proyecto${total == 1 ? '' : 's'}</span>
        </div>

        <%-- Filtros --%>
        <div class="p-3 border-bottom bg-light">
          <form method="get" class="row g-2 align-items-end">
            <div class="col-md-4">
              <label class="form-label small fw-bold mb-1">Buscar</label>
              <input type="text" name="q" class="form-control form-control-sm"
                     placeholder="Código, título, nombre o documento"
                     value="${fn:escapeXml(q)}">
            </div>
            <div class="col-md-2">
              <label class="form-label small fw-bold mb-1">Fase</label>
              <select name="fase" class="form-select form-select-sm">
                <option value="">Todas</option>
                <c:forEach begin="1" end="6" var="f">
                  <option value="${f}" ${filtroFase == f ? 'selected' : ''}>Fase ${f}</option>
                </c:forEach>
              </select>
            </div>
            <div class="col-md-2">
              <label class="form-label small fw-bold mb-1">Estado</label>
              <select name="estado" class="form-select form-select-sm">
                <option value="">Todos</option>
                <option value="En curso"   ${filtroEstado == 'En curso'   ? 'selected' : ''}>En curso</option>
                <option value="Rechazado"  ${filtroEstado == 'Rechazado'  ? 'selected' : ''}>Rechazado</option>
                <option value="Cancelado"  ${filtroEstado == 'Cancelado'  ? 'selected' : ''}>Cancelado</option>
                <option value="Finalizado" ${filtroEstado == 'Finalizado' ? 'selected' : ''}>Finalizado</option>
              </select>
            </div>
            <div class="col-md-2">
              <label class="form-label small fw-bold mb-1">Mostrar</label>
              <select name="limite" class="form-select form-select-sm">
                <option value="10"  ${limite == 10  ? 'selected' : ''}>10</option>
                <option value="25"  ${limite == 25  ? 'selected' : ''}>25</option>
                <option value="50"  ${limite == 50  ? 'selected' : ''}>50</option>
                <option value="100" ${limite == 100 ? 'selected' : ''}>100</option>
              </select>
            </div>
            <div class="col-md-2 d-flex gap-1">
              <button type="submit" class="btn btn-uts btn-sm">
                <i class="fas fa-search me-1"></i>Filtrar
              </button>
              <a href="proyectos.jsp" class="btn btn-outline-secondary btn-sm">Limpiar</a>
            </div>
          </form>
        </div>

        <div class="p-0">
          <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
              <thead class="table-light">
                <tr>
                  <th>Código</th>
                  <th>Título</th>
                  <th>Integrantes</th>
                  <th>Fase</th>
                  <th>Estado</th>
                  <th>Responsable</th>
                  <th>Director / Evaluador</th>
                  <th style="text-align:center">Acciones</th>
                </tr>
              </thead>
              <tbody>
                <c:forEach items="${proyectos.rows}" var="p">
                  <tr>
                    <td><strong>${p.codigo}</strong></td>
                    <td>
                      <div class="fw-semibold">${p.titulo}</div>
                      <small class="text-muted">${p.tipo_modalidad} · ${p.tipo_nivel}</small>
                    </td>
                    <td>
                      <small>${p.estudiantes_info}</small>
                    </td>
                    <td>
                      <span class="badge bg-primary">Fase ${p.fase}</span>
                    </td>
                    <td>
                      <c:choose>
                        <c:when test="${p.estado == 'En curso'}">
                          <span class="badge bg-success">En curso</span>
                        </c:when>
                        <c:when test="${p.estado == 'Rechazado'}">
                          <span class="badge bg-danger">Rechazado</span>
                        </c:when>
                        <c:when test="${p.estado == 'Cancelado'}">
                          <span class="badge bg-secondary">Cancelado</span>
                        </c:when>
                        <c:when test="${p.estado == 'Finalizado'}">
                          <span class="badge bg-info text-dark">Finalizado</span>
                        </c:when>
                        <c:otherwise>
                          <span class="badge bg-light text-dark">${p.estado}</span>
                        </c:otherwise>
                      </c:choose>
                    </td>
                    <td>
                      <c:choose>
                        <c:when test="${p.responsable == 'comite'}">
                          <span class="badge bg-warning text-dark">Comité</span>
                        </c:when>
                        <c:when test="${p.responsable == 'estudiante'}">
                          <span class="badge bg-secondary">Estudiante</span>
                        </c:when>
                        <c:when test="${p.responsable == 'director'}">
                          <span class="badge bg-primary">Director</span>
                        </c:when>
                        <c:when test="${p.responsable == 'evaluador'}">
                          <span class="badge bg-info text-dark">Evaluador</span>
                        </c:when>
                      </c:choose>
                    </td>
                    <td>
                      <small>
                        Dir: <c:choose><c:when test="${empty p.director_nombre}">Sin asignar</c:when><c:otherwise>${p.director_nombre}</c:otherwise></c:choose><br>
                        Eval: <c:choose><c:when test="${empty p.evaluador_nombre}">Sin asignar</c:when><c:otherwise>${p.evaluador_nombre}</c:otherwise></c:choose>
                        <c:if test="${not empty p.codirector_nombre}"><br>Codir: ${p.codirector_nombre}</c:if>
                      </small>
                    </td>
                    <td style="text-align:center; white-space:nowrap">
                      <%-- 1. Ver detalles --%>
                      <button class="btn-action btn-ver" data-bs-toggle="modal"
                              data-bs-target="#detalle${p.id}" title="Ver detalles">
                        <i class="fas fa-eye"></i>
                      </button>
                      <%-- 2. Seguimiento (mapa de fases) --%>
                      <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}"
                         class="btn-action btn-seguimiento ms-1" title="Seguimiento de fases">
                        <i class="fas fa-map-marked-alt"></i>
                      </a>
                      <%-- 3. Reasignar tribunal --%>
                      <c:if test="${p.estado == 'En curso' and p.fase > 1}">
                        <button class="btn-action btn-seguimiento ms-1" data-bs-toggle="modal"
                                data-bs-target="#reasignar${p.id}" title="Reasignar tribunal">
                          <i class="fas fa-user-edit"></i>
                        </button>
                      </c:if>
                      <%-- 4. Cancelar --%>
                      <c:if test="${p.estado == 'En curso'}">
                        <button class="btn-action btn-retirar ms-1" data-bs-toggle="modal"
                                data-bs-target="#cancelar${p.id}" title="Cancelar proyecto">
                          <i class="fas fa-ban"></i>
                        </button>
                      </c:if>
                    </td>
                  </tr>

                  <%-- Modal Detalles --%>
                  <div class="modal fade" id="detalle${p.id}" tabindex="-1">
                    <div class="modal-dialog modal-lg modal-dialog-scrollable">
                      <div class="modal-content">
                        <div class="modal-header modal-header-sigrado">
                          <h5 class="modal-title">${p.codigo} — ${p.titulo}</h5>
                          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                          <div class="row g-3">
                            <div class="col-12">
                              <strong>Integrantes:</strong><br>
                              <small>${p.estudiantes_info}</small>
                            </div>
                            <div class="col-md-6">
                              <strong>Director:</strong>
                              <c:choose>
                                <c:when test="${empty p.director_nombre}">No asignado</c:when>
                                <c:otherwise>${p.director_nombre}</c:otherwise>
                              </c:choose>
                            </div>
                            <div class="col-md-6">
                              <strong>Evaluador:</strong>
                              <c:choose>
                                <c:when test="${empty p.evaluador_nombre}">No asignado</c:when>
                                <c:otherwise>${p.evaluador_nombre}</c:otherwise>
                              </c:choose>
                            </div>
                            <c:if test="${not empty p.codirector_nombre}">
                              <div class="col-md-6">
                                <strong>Codirector:</strong> ${p.codirector_nombre}
                              </div>
                            </c:if>
                            <div class="col-md-6"><strong>Modalidad:</strong> ${p.tipo_modalidad}</div>
                            <div class="col-md-6"><strong>Nivel:</strong> ${p.tipo_nivel}</div>
                            <div class="col-md-6">
                              <strong>Fase actual:</strong>
                              <span class="badge bg-primary">Fase ${p.fase}</span>
                            </div>
                            <div class="col-md-6">
                              <strong>Responsable actual:</strong>
                              <span class="badge bg-secondary">${p.responsable}</span>
                            </div>
                            <c:if test="${not empty p.codigo_modalidad}">
                              <div class="col-md-6"><strong>Código modalidad:</strong> ${p.codigo_modalidad}</div>
                            </c:if>
                            <div class="col-12"><strong>Objetivo general:</strong><p class="mt-1">${p.objetivo_general}</p></div>
                            <div class="col-12"><strong>Descripción:</strong><p class="mt-1">${p.descripcion}</p></div>
                            <div class="col-md-6">
                              <strong>Creado:</strong> <fmt:formatDate value="${p.fecha_creacion}" pattern="dd/MM/yyyy HH:mm"/>
                            </div>
                            <div class="col-md-6">
                              <strong>Actualizado:</strong> <fmt:formatDate value="${p.fecha_actualizacion}" pattern="dd/MM/yyyy HH:mm"/>
                            </div>
                          </div>
                        </div>
                        <div class="modal-footer">
                          <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                        </div>
                      </div>
                    </div>
                  </div>

                  <%-- Modal Reasignar Tribunal --%>
                  <c:if test="${p.estado == 'En curso' and p.fase > 1}">
                    <div class="modal fade" id="reasignar${p.id}" tabindex="-1">
                      <div class="modal-dialog modal-dialog-centered">
                        <form method="post" action="proyectos.jsp" class="modal-content">
                          <input type="hidden" name="accion"      value="reasignar"/>
                          <input type="hidden" name="proyecto_id" value="${p.id}"/>
                          <div class="modal-header modal-header-sigrado">
                            <h5 class="modal-title">Reasignar Tribunal — ${p.codigo}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                          </div>
                          <div class="modal-body row g-3">
                            <div class="col-12">
                              <div class="alert alert-info small mb-0">
                                Tribunal de 2: director y evaluador (diferentes). Ambos salen de la misma lista de docentes.
                              </div>
                            </div>
                            <div class="col-12">
                              <label class="form-label fw-bold small">Nuevo Director</label>
                              <select name="nuevo_director_id" class="form-select form-select-sm">
                                <option value="">— Sin cambiar —</option>
                                <c:forEach items="${docentesList.rows}" var="doc">
                                  <option value="${doc.id}" ${p.director_id == doc.id ? 'selected' : ''}>${doc.nombre}</option>
                                </c:forEach>
                              </select>
                            </div>
                            <div class="col-12">
                              <label class="form-label fw-bold small">Nuevo Evaluador</label>
                              <select name="nuevo_evaluador_id" class="form-select form-select-sm">
                                <option value="">— Sin cambiar —</option>
                                <c:forEach items="${docentesList.rows}" var="doc">
                                  <option value="${doc.id}" ${p.evaluador_id == doc.id ? 'selected' : ''}>${doc.nombre}</option>
                                </c:forEach>
                              </select>
                            </div>
                          </div>
                          <div class="modal-footer">
                            <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                            <button type="submit" class="btn btn-uts btn-sm">Guardar Cambios</button>
                          </div>
                        </form>
                      </div>
                    </div>
                  </c:if>

                  <%-- Modal Cancelar Proyecto --%>
                  <c:if test="${p.estado == 'En curso'}">
                    <div class="modal fade" id="cancelar${p.id}" tabindex="-1">
                      <div class="modal-dialog modal-dialog-centered">
                        <form method="post" action="proyectos.jsp" class="modal-content">
                          <input type="hidden" name="accion"      value="cancelar"/>
                          <input type="hidden" name="proyecto_id" value="${p.id}"/>
                          <div class="modal-header bg-danger text-white">
                            <h5 class="modal-title"><i class="fas fa-ban me-2"></i>Cancelar Proyecto</h5>
                            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                          </div>
                          <div class="modal-body">
                            <div class="alert alert-warning small">
                              <i class="fas fa-exclamation-triangle me-1"></i>
                              Esta acción cancelará el proyecto <strong>${p.codigo}</strong> definitivamente.
                            </div>
                            <label class="form-label fw-bold small">Motivo de cancelación</label>
                            <textarea name="motivo" class="form-control form-control-sm" rows="3"
                                      placeholder="Ingrese el motivo de cancelación..."></textarea>
                          </div>
                          <div class="modal-footer">
                            <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                            <button type="submit" class="btn btn-danger btn-sm">
                              <i class="fas fa-ban me-1"></i>Confirmar Cancelación
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                  </c:if>

                </c:forEach>

                <c:if test="${proyectos.rowCount == 0}">
                  <tr>
                    <td colspan="8" class="text-center py-5 text-muted">
                      <i class="fas fa-inbox fa-2x mb-2 d-block"></i>
                      No se encontraron proyectos con los filtros aplicados.
                    </td>
                  </tr>
                </c:if>
              </tbody>
            </table>
          </div>

          <%-- Paginación --%>
          <div class="p-3 border-top d-flex justify-content-between align-items-center flex-wrap gap-2">
            <small class="text-muted">
              Mostrando página <strong>${pagina}</strong> de
              <strong>${totalPaginas > 0 ? totalPaginas : 1}</strong>
              — ${total} resultado${total == 1 ? '' : 's'}
            </small>
            <nav>
              <ul class="pagination pagination-sm mb-0">
                <c:if test="${pagina > 1}">
                  <li class="page-item">
                    <a class="page-link" href="proyectos.jsp?pagina=${pagina-1}&limite=${limite}&q=${fn:escapeXml(q)}&fase=${filtroFase}&estado=${filtroEstado}">‹</a>
                  </li>
                </c:if>
                <c:forEach begin="1" end="${totalPaginas}" var="i">
                  <li class="page-item ${i == pagina ? 'active' : ''}">
                    <a class="page-link" href="proyectos.jsp?pagina=${i}&limite=${limite}&q=${fn:escapeXml(q)}&fase=${filtroFase}&estado=${filtroEstado}">${i}</a>
                  </li>
                </c:forEach>
                <c:if test="${pagina < totalPaginas}">
                  <li class="page-item">
                    <a class="page-link" href="proyectos.jsp?pagina=${pagina+1}&limite=${limite}&q=${fn:escapeXml(q)}&fase=${filtroFase}&estado=${filtroEstado}">›</a>
                  </li>
                </c:if>
              </ul>
            </nav>
          </div>

        </div>
      </div>
    </div>
    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>