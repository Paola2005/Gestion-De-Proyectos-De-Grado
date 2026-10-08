<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardComite.jspf" %>

<%-- Procesamiento de decisión del Comité sobre propuesta de banco --%>
<c:if test="${param.accion == 'evaluar_propuesta' and not empty param.propuesta_id}">
<c:catch var="errEval">
    <sql:update dataSource="${db}">
      UPDATE propuestas_banco 
      SET estado = ?, 
          disponible = ?, 
          fecha_revision = NOW(), 
          comite_revisor_id = ?, 
          observacion_comite = ? 
      WHERE id = ?
      <sql:param value="${param.decision}"/>
      <sql:param value="${param.decision == 'Aprobada' ? 1 : 0}"/>
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="${param.observaciones}"/>
      <sql:param value="${param.propuesta_id}"/>
    </sql:update>
    <c:redirect url="/comite/banco.jsp">
      <c:param name="ok" value="Decisión registrada exitosamente"/>
    </c:redirect>
  </c:catch>
  <c:if test="${not empty errEval}">
    <c:set var="errorMsg" value="Error al procesar la decisión. Intente de nuevo." />
  </c:if>
</c:if>

<%-- Paginación y búsqueda --%>
<c:set var="limite" value="${empty param.limite ? 5 : param.limite}" />
<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}" />
<c:set var="offset" value="${(pagina - 1) * limite}" />
<c:set var="clave" value="${param.clave}" />

<c:choose>
  <c:when test="${not empty clave}">
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(*) AS total FROM propuestas_banco pb
      JOIN usuarios u ON pb.docente_id = u.id
      WHERE pb.codigo LIKE ? OR pb.titulo LIKE ? OR u.nombres LIKE ? OR u.apellidos LIKE ?
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
    </sql:query>
    <sql:query dataSource="${db}" var="propuestas">
      SELECT pb.*, CONCAT(u.nombres, ' ', u.apellidos) AS docente_nombre, per.codigo AS periodo_codigo
      FROM propuestas_banco pb
      JOIN usuarios u ON pb.docente_id = u.id
      JOIN periodos per ON pb.periodo_id = per.id
      WHERE pb.codigo LIKE ? OR pb.titulo LIKE ? OR u.nombres LIKE ? OR u.apellidos LIKE ?
      ORDER BY pb.id DESC
      LIMIT ${limite} OFFSET ${offset}
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(*) AS total FROM propuestas_banco
    </sql:query>
    <sql:query dataSource="${db}" var="propuestas">
      SELECT pb.*, CONCAT(u.nombres, ' ', u.apellidos) AS docente_nombre, per.codigo AS periodo_codigo
      FROM propuestas_banco pb
      JOIN usuarios u ON pb.docente_id = u.id
      JOIN periodos per ON pb.periodo_id = per.id
      ORDER BY pb.id DESC
      LIMIT ${limite} OFFSET ${offset}
    </sql:query>
  </c:otherwise>
</c:choose>

<c:set var="totalRegistros" value="${conteo.rows[0].total}" />
<c:set var="totalPaginas" value="${((totalRegistros + limite - 1) / limite)}" />

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Propuestas BANCO - SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <%-- Mensajes de estado --%>
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-check-circle me-1"></i> <c:out value="${param.ok}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty errorMsg}">
        <div class="alert alert-danger alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-exclamation-triangle me-1"></i> <c:out value="${errorMsg}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <div class="card-sigrado">
        <div class="card-header-custom">
          <h2 class="page-title">
            Propuestas <span class="badge-title-box">BANCO</span>
          </h2>
          <div class="d-flex gap-2">
            <span class="btn-icon-sq btn-icon-danger" title="Notificaciones"><i class="fas fa-exclamation-triangle"></i></span>
            <span class="btn-icon-sq btn-icon-eye" title="Documentos"><i class="fas fa-file-alt"></i></span>
            <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-3">
          <%-- Controles de búsqueda y paginador idénticos al PDF (Pág. 2) --%>
          <form method="get" action="banco.jsp" class="table-controls">
            <div class="d-flex align-items-center gap-2">
              <span class="small text-muted">Mostrar</span>
              <select name="limite" class="form-select form-select-sm" style="width: 75px;" onchange="this.form.submit()">
                <option value="5" ${limite == 5 ? 'selected' : ''}>5</option>
                <option value="10" ${limite == 10 ? 'selected' : ''}>10</option>
                <option value="25" ${limite == 25 ? 'selected' : ''}>25</option>
              </select>
              <span class="small text-muted">registros por página</span>
            </div>

            <div class="d-flex align-items-center gap-2">
              <span class="small text-muted">Buscar:</span>
              <input type="text" name="clave" class="form-control form-control-sm" style="width: 220px;" 
                     placeholder="ingrese una clave" value="${fn:escapeXml(clave)}">
              <button type="submit" class="btn btn-uts btn-sm"><i class="fas fa-search"></i></button>
            </div>
          </form>

          <%-- Tabla institucional de propuestas banco (Pág. 2) --%>
          <div class="table-responsive">
            <table class="table-sigrado">
              <thead>
                <tr>
                  <th style="width: 120px;">ID <i class="fas fa-sort text-muted ms-1"></i></th>
                  <th>Descripción</th>
                  <th>Docente responsable</th>
                  <th style="width: 130px; text-align: center;">Estado</th>
                  <th style="width: 110px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
                <c:choose>
                  <c:when test="${propuestas.rowCount > 0}">
                    <c:forEach var="p" items="${propuestas.rows}">
                      <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td>${p.titulo}</td>
                        <td>${p.docente_nombre}</td>
                        <td style="text-align: center;">
                          <c:choose>
                            <c:when test="${p.estado == 'Aprobada'}">
                              <span class="badge-pill-custom badge-aprobado">Aprobada</span>
                            </c:when>
                            <c:when test="${p.estado == 'Rechazada'}">
                              <span class="badge-pill-custom badge-rechazado">Rechazada</span>
                            </c:when>
                            <c:otherwise>
                              <span class="badge-pill-custom badge-pendiente">Pendiente</span>
                            </c:otherwise>
                          </c:choose>
                        </td>
                        <td style="text-align: center;">
                          <%-- Botón OJO: modal detalles de propuesta (Pág. 2 y 3) --%>
                          <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalDetalle${p.id}" title="Ver detalles">
                            <i class="fas fa-eye"></i>
                          </button>
                          <%-- Botón RESPONDER: modal evaluar propuesta --%>
                          <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalEval${p.id}" title="Aprobar o Rechazar">
                            <i class="fas fa-check-square"></i>
                          </button>
                        </td>
                      </tr>

                      <%-- MODAL: Detalles de la PROPUESTA (Exacto al PDF Pág. 2 y 3) --%>
                      <div class="modal fade" id="modalDetalle${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered modal-lg">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">
                                Detalles de la <span class="badge-title-box">PROPUESTA</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body p-4">
                              <div class="row">
                                <div class="col-md-6">
                                  <div class="detail-label">Docente responsable</div>
                                  <div class="detail-value">${p.docente_nombre}</div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Tipo de modalidad</div>
                                  <div class="detail-value">${p.tipo_modalidad}</div>
                                </div>
                              </div>
                              <div class="row">
                                <div class="col-12">
                                  <div class="detail-label">Título de la idea</div>
                                  <div class="detail-value fw-bold text-dark">${p.titulo}</div>
                                </div>
                              </div>
                              <div class="row">
                                <div class="col-12">
                                  <div class="detail-label">Objetivo general de la idea</div>
                                  <div class="detail-value bg-light p-3 rounded border text-muted">${p.objetivo_general}</div>
                                </div>
                              </div>
                              <div class="row mt-2">
                                <div class="col-md-6">
                                  <div class="detail-label">Línea de investigación</div>
                                  <div class="detail-value">${p.linea_investigacion}</div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Tipo de nivel</div>
                                  <div class="detail-value">${p.tipo_nivel}</div>
                                </div>
                              </div>
                              <div class="row">
                                <div class="col-md-6">
                                  <div class="detail-label">Periodo académico</div>
                                  <div class="detail-value">${p.periodo_codigo}</div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Disponible</div>
                                  <div class="detail-value">
                                    <c:choose>
                                      <c:when test="${p.disponible}"><span class="text-success fw-bold">Disponible</span></c:when>
                                      <c:otherwise><span class="text-danger fw-bold">No disponible</span></c:otherwise>
                                    </c:choose>
                                  </div>
                                </div>
                              </div>
                              <c:if test="${not empty p.observacion_comite}">
                                <div class="row mt-2">
                                  <div class="col-12">
                                    <div class="detail-label">Observaciones del Comité</div>
                                    <div class="detail-value bg-light p-2 rounded border">${p.observacion_comite}</div>
                                  </div>
                                </div>
                              </c:if>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm px-4" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%-- MODAL: Evaluar Propuesta de Banco por el Comité --%>
                      <div class="modal fade" id="modalEval${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered">
                          <div class="modal-content">
                            <form method="post" action="banco.jsp">
                              <input type="hidden" name="accion" value="evaluar_propuesta">
                              <input type="hidden" name="propuesta_id" value="${p.id}">
                              <div class="modal-header modal-header-sigrado">
                                <h5 class="modal-title fw-bold">
                                  Evaluar <span class="badge-title-box">PROPUESTA</span>
                                </h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                              </div>
                              <div class="modal-body p-4">
                                <div class="mb-3">
                                  <label class="form-label small fw-bold">Propuesta:</label>
                                  <div class="text-muted small">${p.codigo} - ${p.titulo}</div>
                                </div>
                                <div class="mb-3">
                                  <label class="form-label small fw-bold">Decisión del Comité *</label>
                                  <select name="decision" class="form-select form-select-sm" required>
                                    <option value="Aprobada" ${p.estado == 'Aprobada' ? 'selected' : ''}>Aprobar (Disponible para asignación)</option>
                                    <option value="Rechazada" ${p.estado == 'Rechazada' ? 'selected' : ''}>Rechazar</option>
                                  </select>
                                </div>
                                <div class="mb-3">
                                  <label class="form-label small fw-bold">Observaciones / Justificación</label>
                                  <textarea name="observaciones" class="form-control form-control-sm" rows="3" placeholder="Ingrese comentarios para el docente...">${p.observacion_comite}</textarea>
                                </div>
                              </div>
                              <div class="modal-footer modal-footer-sigrado">
                                <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                <button type="submit" class="btn btn-uts btn-sm">Guardar Decisión</button>
                              </div>
                            </form>
                          </div>
                        </div>
                      </div>

                    </c:forEach>
                  </c:when>
                  <c:otherwise>
                    <tr>
                      <td colspan="5" class="text-center py-4 text-muted">
                        <i class="fas fa-folder-open fa-2x mb-2 d-block"></i>
                        No se encontraron propuestas registradas
                      </td>
                    </tr>
                  </c:otherwise>
                </c:choose>
              </tbody>
            </table>
          </div>

          <%-- Paginador idéntico al PDF --%>
          <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap">
            <div class="small text-muted">
              Mostrando registros de ${offset + 1} a ${offset + propuestas.rowCount} de un total de ${totalRegistros}
            </div>
            <div class="d-flex gap-1">
              <c:if test="${pagina > 1}">
                <a href="banco.jsp?pagina=${pagina - 1}&limite=${limite}&clave=${clave}" class="btn btn-outline-secondary btn-sm">Anterior</a>
              </c:if>
              <span class="btn btn-uts btn-sm">${pagina}</span>
              <c:if test="${pagina < totalPaginas}">
                <a href="banco.jsp?pagina=${pagina + 1}&limite=${limite}&clave=${clave}" class="btn btn-outline-secondary btn-sm">Siguiente</a>
              </c:if>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>


