<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardAdministrador.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<%-- Procesamiento: Eliminar formato --%>
<c:if test="${param.accion == 'eliminar' and not empty param.id}">
  <sql:update dataSource="${db}">DELETE FROM formatos WHERE id=?<sql:param value="${param.id}"/></sql:update>
  <c:redirect url="/administrador/formatos.jsp"><c:param name="ok" value="Formato eliminado"/></c:redirect>
</c:if>

<%-- Procesamiento: Crear/Editar formato --%>
<c:if test="${param.accion == 'guardar'}">
  <c:catch var="errFmt">
    <c:if test="${empty param.codigo or empty param.nombre or empty param.url}">
      <c:redirect url="/administrador/formatos.jsp"><c:param name="error" value="Todos los campos son obligatorios"/></c:redirect>
    </c:if>
    <c:if test="${not fn:startsWith(param.url,'https://')}">
      <c:redirect url="/administrador/formatos.jsp"><c:param name="error" value="Todo documento es una URL https; no se suben archivos."/></c:redirect>
    </c:if>
    <c:choose>
      <c:when test="${empty param.id}">
        <sql:update dataSource="${db}">
          INSERT INTO formatos (codigo, nombre, url, activo) VALUES (?, ?, ?, 1)
          <sql:param value="${param.codigo}"/><sql:param value="${param.nombre}"/><sql:param value="${param.url}"/>
        </sql:update>
      </c:when>
      <c:otherwise>
        <sql:update dataSource="${db}">
          UPDATE formatos SET codigo=?, nombre=?, url=?, activo=? WHERE id=?
          <sql:param value="${param.codigo}"/><sql:param value="${param.nombre}"/><sql:param value="${param.url}"/>
          <sql:param value="${param.activo}"/><sql:param value="${param.id}"/>
        </sql:update>
      </c:otherwise>
    </c:choose>
    <c:redirect url="/administrador/formatos.jsp"><c:param name="ok" value="Formato guardado"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errFmt}">
    <c:redirect url="/administrador/formatos.jsp"><c:param name="error" value="Error al guardar el formato. Intente de nuevo."/></c:redirect>
  </c:if>
</c:if>

<sql:query dataSource="${db}" var="formatos">
  SELECT * FROM formatos ORDER BY codigo
</sql:query>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Formatos de Grado - Administrador · SIGRADO UTS</title>
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

      <div class="card-sigrado">
        <div class="card-header-custom">
          <div>
            <h2 class="page-title">
              Formatos de <span class="badge-title-box">GRADO</span>
            </h2>
            <div class="small text-muted mt-1">
              Crear, editar y eliminar formatos institucionales (F-DC-124, 125, 129...)
            </div>
          </div>
          <button class="btn btn-uts btn-sm" data-bs-toggle="modal" data-bs-target="#modalFormato">
            <i class="fas fa-plus me-1"></i> Nuevo Formato
          </button>
        </div>

        <div class="p-3">
          <div class="table-responsive">
            <table class="table-sigrado">
              <thead>
                <tr>
                  <th style="width: 100px;">Código</th>
                  <th>Nombre</th>
                  <th>URL</th>
                  <th style="width: 80px; text-align: center;">Estado</th>
                  <th style="width: 120px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
                <c:forEach var="f" items="${formatos.rows}">
                  <tr>
                    <td class="fw-bold">${f.codigo}</td>
                    <td>${f.nombre}</td>
                    <td>
                      <a href="${f.url}" target="_blank" class="text-truncate d-inline-block" style="max-width: 300px;">${f.url}</a>
                    </td>
                    <td style="text-align: center;">
                      <c:choose>
                        <c:when test="${f.activo}"><span class="badge bg-success">Activo</span></c:when>
                        <c:otherwise><span class="badge bg-secondary">Inactivo</span></c:otherwise>
                      </c:choose>
                    </td>
                    <td style="text-align: center;">
                      <button class="btn-action btn-ver ms-1" data-bs-toggle="modal" data-bs-target="#modalFormato" 
                              onclick="cargarFormato(${f.id}, '${fn:escapeXml(f.codigo)}', '${fn:escapeXml(f.nombre)}', '${fn:escapeXml(f.url)}', ${f.activo})" 
                              title="Editar">
                        <i class="fas fa-edit"></i>
                      </button>
                      <a href="formatos.jsp?accion=eliminar&id=${f.id}" class="btn-action btn-retirar ms-1" 
                         onclick="return confirm('¿Eliminar este formato?')" title="Eliminar">
                        <i class="fas fa-trash"></i>
                      </a>
                    </td>
                  </tr>
                </c:forEach>
                <c:if test="${formatos.rowCount == 0}">
                  <tr><td colspan="5" class="text-center py-4 text-muted">No hay formatos registrados</td></tr>
                </c:if>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <%-- Modal Nuevo/Editar Formato --%>
      <div class="modal fade" id="modalFormato" tabindex="-1" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-lg">
          <form method="post" action="formatos.jsp" class="modal-content">
            <input type="hidden" name="accion" value="guardar"/>
            <input type="hidden" name="id" id="fmt_id"/>
            <div class="modal-header modal-header-sigrado">
              <h5 class="modal-title fw-bold" id="fmt_titulo">Nuevo Formato</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body p-4 row g-3">
              <div class="col-md-4">
                <label class="form-label small fw-bold">Código *</label>
                <input type="text" name="codigo" id="fmt_codigo" class="form-control form-control-sm" required placeholder="F-DC-124">
              </div>
              <div class="col-md-8">
                <label class="form-label small fw-bold">Nombre *</label>
                <input type="text" name="nombre" id="fmt_nombre" class="form-control form-control-sm" required placeholder="Formato Propuesta Trabajo de Grado">
              </div>
              <div class="col-12">
                <label class="form-label small fw-bold">URL *</label>
                <input type="url" name="url" id="fmt_url" class="form-control form-control-sm" required placeholder="https://drive.google.com/file/d/.../view">
              </div>
              <div class="col-md-4">
                <label class="form-label small fw-bold">Estado</label>
                <select name="activo" id="fmt_activo" class="form-select form-select-sm">
                  <option value="1">Activo</option>
                  <option value="0">Inactivo</option>
                </select>
              </div>
            </div>
            <div class="modal-footer modal-footer-sigrado">
              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
              <button type="submit" class="btn btn-uts btn-sm">Guardar</button>
            </div>
          </form>
        </div>
      </div>

      <script>
        function cargarFormato(id, codigo, nombre, url, activo) {
          document.getElementById('fmt_id').value = id;
          document.getElementById('fmt_codigo').value = codigo;
          document.getElementById('fmt_nombre').value = nombre;
          document.getElementById('fmt_url').value = url;
          document.getElementById('fmt_activo').value = activo;
          document.getElementById('fmt_titulo').textContent = 'Editar Formato';
        }
        document.getElementById('modalFormato').addEventListener('hidden.bs.modal', function() {
          document.getElementById('fmt_id').value = '';
          document.getElementById('fmt_codigo').value = '';
          document.getElementById('fmt_nombre').value = '';
          document.getElementById('fmt_url').value = '';
          document.getElementById('fmt_activo').value = '1';
          document.getElementById('fmt_titulo').textContent = 'Nuevo Formato';
        });
      </script>

    </div>
    <%@ include file="/WEB-INF/jspf/footer.jspf" %>
  </div>
</body>
</html>