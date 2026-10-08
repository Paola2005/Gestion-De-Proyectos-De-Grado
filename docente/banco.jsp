<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardDocente.jspf" %>

<%-- Procesar radicación de nueva propuesta al banco por el docente (usa periodo activo, sin comprobante según flujo) --%>
<c:if test="${param.accion == 'crear_propuesta'}">
  <c:catch var="errNueva">
    <sql:query dataSource="${db}" var="perAct">
      SELECT id, (CURDATE() BETWEEN inicio_propuestas_banco AND fin_propuestas_banco) AS en_ventana
      FROM periodos WHERE activo=1 LIMIT 1
    </sql:query>
    <c:if test="${perAct.rowCount == 0}">
      <c:redirect url="/docente/banco.jsp"><c:param name="error" value="No hay periodo académico activo. Contacte al administrador."/></c:redirect>
    </c:if>
    <c:if test="${perAct.rows[0].en_ventana != 1}">
      <c:redirect url="/docente/banco.jsp"><c:param name="error" value="Fuera de las fechas del periodo activo para proponer ideas al banco."/></c:redirect>
    </c:if>
    <%-- Generar código secuencial BAN-00000 --%>
    <sql:query dataSource="${db}" var="ultCod">
      SELECT COALESCE(MAX(id), 0) + 1 AS siguiente_id FROM propuestas_banco
    </sql:query>
    <c:set var="nuevoCodigo" value="BAN-${fn:substring('00000',0,5 - fn:length(ultCod.rows[0].siguiente_id))}${ultCod.rows[0].siguiente_id}" />
    <sql:update dataSource="${db}">
      INSERT INTO propuestas_banco (codigo, docente_id, titulo, tipo_modalidad, objetivo_general, linea_investigacion, tipo_nivel, periodo_id, estado, disponible)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Pendiente', 1)
      <sql:param value="${nuevoCodigo}"/>
      <sql:param value="${sessionScope.usuario_id}"/>
      <sql:param value="${param.titulo}"/>
      <sql:param value="${param.tipo_modalidad}"/>
      <sql:param value="${param.objetivo_general}"/>
      <sql:param value="${param.linea_investigacion}"/>
      <sql:param value="${param.tipo_nivel}"/>
      <sql:param value="${perAct.rows[0].id}"/>
    </sql:update>
    <c:redirect url="/docente/banco.jsp"><c:param name="ok" value="Propuesta radicada exitosamente en el Banco de Ideas."/></c:redirect>
  </c:catch>
  <c:if test="${not empty errNueva}">
    <c:set var="errorMsg" value="Error al radicar propuesta. Intente de nuevo."/>
  </c:if>
</c:if>

<%-- Consultar propuestas del docente conectado --%>
<sql:query dataSource="${db}" var="misPropuestas">
  SELECT pb.*, per.codigo AS periodo_codigo
  FROM propuestas_banco pb
  JOIN periodos per ON pb.periodo_id = per.id
  WHERE pb.docente_id = ?
  ORDER BY pb.id DESC
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Banco de Ideas - Docente SIGRADO UTS</title>
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
      <c:if test="${not empty errorMsg}">
        <div class="alert alert-danger alert-dismissible fade show py-2 small" role="alert">
          <i class="fas fa-exclamation-triangle me-1"></i> <c:out value="${errorMsg}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">
              Propuestas <span class="badge-title-box">BANCO</span>
            </h2>
            <div class="small text-muted mt-1">
              Registro y administración de propuestas institucionales para trabajos de grado (Pág. 13)
            </div>
          </div>
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-uts btn-sm" data-bs-toggle="modal" data-bs-target="#modalNuevaPropuesta">
              <i class="fas fa-plus me-1"></i> + Crear Nueva Propuesta
            </button>
            <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-3">
          <div class="table-responsive">
            <table class="table-sigrado">
              <thead>
                <tr>
                  <th style="width: 120px;">Código</th>
                  <th>Título / Descripción</th>
                  <th>Modalidad</th>
                  <th>Nivel</th>
                  <th style="width: 130px; text-align: center;">Estado Comité</th>
                  <th style="width: 100px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
                <c:choose>
                  <c:when test="${misPropuestas.rowCount > 0}">
                    <c:forEach var="p" items="${misPropuestas.rows}">
                      <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td>${p.titulo}</td>
                        <td>${p.tipo_modalidad}</td>
                        <td>${p.tipo_nivel}</td>
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
                          <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalVer${p.id}" title="Ver detalles">
                            <i class="fas fa-eye"></i>
                          </button>
                        </td>
                      </tr>

                      <%-- MODAL Ver Detalle Propuesta --%>
                      <div class="modal fade" id="modalVer${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered modal-lg">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">Detalles de la <span class="badge-title-box">PROPUESTA</span></h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body p-4">
                              <div class="mb-3">
                                <div class="detail-label">Título de la propuesta</div>
                                <div class="detail-value fw-bold">${p.titulo}</div>
                              </div>
                              <div class="mb-3">
                                <div class="detail-label">Objetivo general</div>
                                <div class="detail-value bg-light p-3 rounded border text-muted">${p.objetivo_general}</div>
                              </div>
                              <div class="row">
                                <div class="col-md-6">
                                  <div class="detail-label">Modalidad</div>
                                  <div class="detail-value">${p.tipo_modalidad}</div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Línea de investigación</div>
                                  <div class="detail-value">${p.linea_investigacion}</div>
                                </div>
                              </div>
                              <div class="row">
                                <div class="col-md-6">
                                  <div class="detail-label">Nivel académico</div>
                                  <div class="detail-value">${p.tipo_nivel}</div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Estado de revisión</div>
                                  <div class="detail-value"><strong>${p.estado}</strong></div>
                                </div>
                              </div>
                              <c:if test="${not empty p.observacion_comite}">
                                <div class="mt-3 p-3 bg-light rounded border">
                                  <div class="detail-label">Concepto del Comité:</div>
                                  <div>${p.observacion_comite}</div>
                                </div>
                              </c:if>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                    </c:forEach>
                  </c:when>
                  <c:otherwise>
                    <tr>
                      <td colspan="6" class="text-center py-4 text-muted">
                        No has registrado propuestas de banco aún. Haz clic en <strong>+ Crear Nueva Propuesta</strong>.
                      </td>
                    </tr>
                  </c:otherwise>
                </c:choose>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </div>

  <%-- MODAL: Crear Nueva Propuesta de Banco --%>
  <div class="modal fade" id="modalNuevaPropuesta" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-dialog-centered modal-lg">
      <div class="modal-content">
        <form method="post" action="banco.jsp">
          <input type="hidden" name="accion" value="crear_propuesta">
          <div class="modal-header modal-header-sigrado">
            <h5 class="modal-title fw-bold">Crear Nueva <span class="badge-title-box">PROPUESTA</span></h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body p-4">
            <div class="mb-3">
              <label class="form-label small fw-bold">Título de la idea *</label>
              <input type="text" name="titulo" class="form-control form-control-sm" required placeholder="Ej: Sistematización de procesos...">
            </div>
            <div class="row">
              <div class="col-md-6 mb-3">
                <label class="form-label small fw-bold">Tipo de modalidad *</label>
                <select name="tipo_modalidad" class="form-select form-select-sm" required>
                  <option value="Desarrollo tecnologico">Desarrollo tecnológico</option>
                  <option value="Emprendimiento">Emprendimiento</option>
                  <option value="Investigacion">Investigación</option>
                  <option value="Otro">Otro</option>
                </select>
              </div>
              <div class="col-md-6 mb-3">
                <label class="form-label small fw-bold">Nivel académico *</label>
                <select name="tipo_nivel" class="form-select form-select-sm" required>
                  <option value="Tecnologico">Tecnológico</option>
                  <option value="Profesional">Profesional</option>
                </select>
              </div>
            </div>
            <div class="mb-3">
              <label class="form-label small fw-bold">Línea de investigación *</label>
              <input type="text" name="linea_investigacion" class="form-control form-control-sm" required placeholder="Ej: Arquitectura y diseño de software">
            </div>
            <div class="mb-3">
              <label class="form-label small fw-bold">Objetivo general de la idea *</label>
              <textarea name="objetivo_general" class="form-control form-control-sm" rows="3" required placeholder="Describe el objetivo general..."></textarea>
            </div>
          </div>
          <div class="modal-footer modal-footer-sigrado">
            <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
            <button type="submit" class="btn btn-uts btn-sm">Radicar Propuesta</button>
          </div>
        </form>
      </div>
    </div>
  </div>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>


