<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardEstudiante.jspf" %>

<%-- Cargar proyecto del estudiante conectado --%>
<c:set var="proyParamId" value="${param.id}"/>
<c:choose>
  <c:when test="${not empty proyParamId}">
    <sql:query dataSource="${db}" var="proyEst">
      SELECT p.*, CONCAT(per.codigo, '') AS periodo_codigo,
             CONCAT(u_dir.nombres, ' ', u_dir.apellidos) AS dir_nom,
             CONCAT(u_cod.nombres, ' ', u_cod.apellidos) AS cod_nom
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      INNER JOIN proyecto_integrantes pi ON p.id = pi.proyecto_id
      LEFT JOIN usuarios u_dir ON p.director_id = u_dir.id
      LEFT JOIN usuarios u_cod ON p.codirector_id = u_cod.id
      WHERE p.id = ? AND pi.usuario_id = ?
      LIMIT 1
      <sql:param value="${proyParamId}"/>
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="proyEst">
      SELECT p.*, CONCAT(per.codigo, '') AS periodo_codigo,
             CONCAT(u_dir.nombres, ' ', u_dir.apellidos) AS dir_nom,
             CONCAT(u_cod.nombres, ' ', u_cod.apellidos) AS cod_nom
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      INNER JOIN proyecto_integrantes pi ON p.id = pi.proyecto_id
      LEFT JOIN usuarios u_dir ON p.director_id = u_dir.id
      LEFT JOIN usuarios u_cod ON p.codirector_id = u_cod.id
      WHERE pi.usuario_id = ?
      ORDER BY p.id DESC
      LIMIT 1
      <sql:param value="${sessionScope.usuario_id}"/>
    </sql:query>
  </c:otherwise>
</c:choose>

<c:if test="${proyEst.rowCount == 0}">
  <c:redirect url="/estudiante/banco.jsp">
    <c:param name="error" value="No tienes un proyecto de grado vinculado."/>
  </c:redirect>
</c:if>

<c:set var="proy" value="${proyEst.rows[0]}" />

<%-- Cargar documentos radicados del proyecto --%>
<sql:query dataSource="${db}" var="docs">
  SELECT * FROM documentos WHERE proyecto_id = ? ORDER BY fase ASC, version DESC
  <sql:param value="${proy.id}"/>
</sql:query>

<%-- Cargar sustentación si existe --%>
<sql:query dataSource="${db}" var="sustEst">
  SELECT * FROM sustentaciones WHERE proyecto_id = ? ORDER BY id DESC LIMIT 1
  <sql:param value="${proy.id}"/>
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Seguimiento de Fases - Estudiante SIGRADO UTS</title>
</head>
<body>
  <%@ include file="/WEB-INF/jspf/sidebar.jspf" %>

  <div class="main-wrapper">
    <%@ include file="/WEB-INF/jspf/topbar.jspf" %>

    <div class="main-content">
      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">
              Seguimiento del <span class="badge-title-box">PROYECTO</span>
            </h2>
            <div class="small text-muted mt-1">
              Aquí podrás ver el seguimiento del progreso de tu trabajo de grado en curso (6 Fases)
            </div>
          </div>
          <div>
            <a href="${pageContext.request.contextPath}/estudiante/proyecto.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-4">
          <div class="p-3 bg-light rounded-3 border mb-4">
            <div class="row align-items-center">
              <div class="col-md-8">
                <span class="badge bg-secondary mb-1">${proy.codigo}</span>
                <h5 class="fw-bold mb-1">${proy.titulo}</h5>
                <div class="small text-muted">
                  Director: <strong>${empty proy.dir_nom ? 'Por asignar por Comité' : proy.dir_nom}</strong> | 
                  Modalidad: ${proy.tipo_modalidad} | Periodo: ${proy.periodo_codigo}
                </div>
              </div>
              <div class="col-md-4 text-md-end">
                <div class="small text-muted">Fase y Turno actual:</div>
                <div class="badge-fase-dual activa-${proy.responsable}">
                  <span class="fase-tag">Fase ${proy.fase}</span>
                  <span class="actor-tag text-uppercase">${proy.responsable}</span>
                </div>
                <div class="small text-muted mt-1">Estado: <strong>${proy.estado}</strong></div>
              </div>
            </div>
          </div>

          <%-- CONTENEDOR DE LAS FASES INTERACTIVAS --%>
          <div class="fases-container">
            
            <%-- FASE 1: PAGO / INSCRIPCIÓN --%>
            <div class="fase-box ${proy.fase >= 1 ? (proy.fase == 1 ? 'activa' : 'superada') : 'pendiente'}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-receipt"></i></div>
                <div class="fase-title">Fase 1: Pago e Inscripción</div>
                <div class="fase-desc">El estudiante sube el soporte de pago. El Comité aprueba y asigna tribunal.</div>
              </div>
              <div class="fase-actions">
                <c:if test="${proy.fase == 1 and proy.responsable == 'estudiante'}">
                  <a href="${pageContext.request.contextPath}/estudiante/versiones.jsp?id=${proy.id}" class="btn btn-dark btn-sm py-1 px-3">
                    Subir Pago
                  </a>
                </c:if>
              </div>
            </div>

            <%-- FASE 2: PROPUESTA I --%>
            <div class="fase-box ${proy.fase >= 2 ? (proy.fase == 2 ? 'activa' : 'superada') : 'pendiente'}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-file-contract"></i></div>
                <div class="fase-title">Fase 2: Propuesta I</div>
                <div class="fase-desc">El estudiante radica la propuesta (F-DC-124) ante su director asignado.</div>
              </div>
              <div class="fase-actions">
                <c:if test="${proy.fase == 2 and proy.responsable == 'estudiante'}">
                  <a href="${pageContext.request.contextPath}/estudiante/versiones.jsp?id=${proy.id}" class="btn btn-dark btn-sm py-1 px-3">
                    Enviar Propuesta
                  </a>
                </c:if>
              </div>
            </div>

            <%-- FASE 3: PROPUESTA II --%>
            <div class="fase-box ${proy.fase >= 3 ? (proy.fase == 3 ? 'activa' : 'superada') : 'pendiente'}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-clipboard-check"></i></div>
                <div class="fase-title">Fase 3: Propuesta II</div>
                <div class="fase-desc">Revisión ciega del docente evaluador y ratificación formal del Comité con acta.</div>
              </div>
              <div class="fase-actions">
                <span class="small text-muted"><i class="fas fa-user-secret me-1"></i> Revisión a ciegas</span>
              </div>
            </div>

            <%-- FASE 4: INFORME I --%>
            <div class="fase-box ${proy.fase >= 4 ? (proy.fase == 4 ? 'activa' : 'superada') : 'pendiente'}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-book"></i></div>
                <div class="fase-title">Fase 4: Informe I</div>
                <div class="fase-desc">El estudiante entrega el informe final (F-DC-125) a su director para aval.</div>
              </div>
              <div class="fase-actions">
                <c:if test="${proy.fase == 4 and proy.responsable == 'estudiante'}">
                  <a href="${pageContext.request.contextPath}/estudiante/versiones.jsp?id=${proy.id}" class="btn btn-dark btn-sm py-1 px-3">
                    Enviar Informe
                  </a>
                </c:if>
              </div>
            </div>

            <%-- FASE 5: INFORME II --%>
            <div class="fase-box ${proy.fase >= 5 ? (proy.fase == 5 ? 'activa' : 'superada') : 'pendiente'}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-tasks"></i></div>
                <div class="fase-title">Fase 5: Informe II</div>
                <div class="fase-desc">Evaluación del informe con Rejilla (F-DC-129) por el evaluador.</div>
              </div>
              <div class="fase-actions">
                <span class="small text-muted"><i class="fas fa-shield-alt me-1"></i> Calificación final</span>
              </div>
            </div>

            <%-- FASE 6: SUSTENTACIÓN Y CIERRE (misma tarjeta y cuadrícula que las demás) --%>
            <div class="fase-box ${proy.fase < 6 ? 'pendiente' : (proy.estado == 'Finalizado' ? 'superada' : 'activa')}">
              <div>
                <div class="fase-icon-circle"><i class="fas fa-graduation-cap"></i></div>
                <div class="fase-title">Fase 6: Sustentación y Cierre</div>
                <div class="fase-desc">Sustentación pública y acta de grado del Comité.</div>
              </div>
              <div class="fase-actions">
                <c:choose>
                  <c:when test="${sustEst.rowCount > 0}">
                    <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalFase6" title="Ver detalles de la sustentación">
                      <i class="fas fa-eye"></i>
                    </button>
                  </c:when>
                  <c:otherwise>
                    <span class="small text-muted">Pendiente</span>
                  </c:otherwise>
                </c:choose>
              </div>
            </div>

          </div>

          <%-- MODAL DETALLES DE LA SUSTENTACIÓN (solo si está registrada) --%>
          <c:if test="${sustEst.rowCount > 0}">
            <c:set var="se" value="${sustEst.rows[0]}"/>
            <div class="modal fade" id="modalFase6" tabindex="-1" aria-labelledby="modalFase6Titulo" aria-hidden="true">
              <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable">
                <div class="modal-content">
                  <div class="modal-header modal-header-sigrado">
                    <h5 class="modal-title fw-bold" id="modalFase6Titulo">Detalles de la sustentación</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button>
                  </div>
                  <div class="modal-body p-4">
                    <div class="fase6-datos text-start">
                      <div class="fase6-fila">
                        <div class="fase6-etiqueta">Resultado</div>
                        <div class="fase6-valor">
                          <c:choose>
                            <c:when test="${se.resultado == 'Aprobado'}"><span class="badge bg-success">Sustentación aprobada</span></c:when>
                            <c:when test="${se.resultado == 'Aplazado'}"><span class="badge bg-warning text-dark">Sustentación aplazada</span></c:when>
                            <c:otherwise><span class="badge bg-danger">Sustentación ${se.resultado}</span></c:otherwise>
                          </c:choose>
                        </div>
                      </div>
                      <div class="fase6-fila">
                        <div class="fase6-etiqueta">Acta N°</div>
                        <div class="fase6-valor">${se.numero_acta}</div>
                      </div>
                      <div class="fase6-fila">
                        <div class="fase6-etiqueta">Fecha y hora</div>
                        <div class="fase6-valor"><fmt:formatDate value="${se.fecha}" pattern="dd/MM/yyyy"/> <fmt:formatDate value="${se.hora}" pattern="HH:mm"/></div>
                      </div>
                      <div class="fase6-fila">
                        <div class="fase6-etiqueta">Lugar o enlace</div>
                        <div class="fase6-valor">
                          <c:choose>
                            <c:when test="${fn:startsWith(se.lugar_o_enlace, 'https://')}">
                              <a href="${se.lugar_o_enlace}" target="_blank" rel="noopener" class="btn btn-outline-primary btn-sm">
                                <i class="fas fa-external-link-alt me-1"></i>Ver enlace
                              </a>
                            </c:when>
                            <c:otherwise>${se.lugar_o_enlace}</c:otherwise>
                          </c:choose>
                        </div>
                      </div>
                      <div class="fase6-fila">
                        <div class="fase6-etiqueta">Jurados</div>
                        <div class="fase6-valor">${se.jurados}</div>
                      </div>
                      <c:if test="${not empty se.observaciones}">
                        <div class="fase6-fila">
                          <div class="fase6-etiqueta">Observaciones</div>
                          <div class="fase6-valor">${se.observaciones}</div>
                        </div>
                      </c:if>
                    </div>
                  </div>
                  <div class="modal-footer modal-footer-sigrado">
                    <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                  </div>
                </div>
              </div>
            </div>
          </c:if>

        </div>
      </div>
    </div>

    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>
