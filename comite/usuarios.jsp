<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>
<%-- Acceso según rol activo elegido; sin elección, según pertenencia (administrador o comité) --%>
<c:if test="${not empty sessionScope.rol_activo ? (sessionScope.rol_activo != 'administrador' and sessionScope.rol_activo != 'comite') : (not fn:contains(sessionScope.roles,'administrador') and not fn:contains(sessionScope.roles,'comite'))}">
  <c:redirect url="/inicio.jsp"><c:param name="error" value="Acceso denegado"/></c:redirect>
</c:if>
<c:set var="esAdmin" value="${not empty sessionScope.rol_activo ? sessionScope.rol_activo == 'administrador' : fn:contains(sessionScope.roles,'administrador')}"/>

<fmt:requestEncoding value="UTF-8"/>

<c:if test="${esAdmin}">
  <%-- ACCIÓN: Crear usuario --%>
  <c:if test="${param.accion == 'crear'}">
    <c:catch var="err">
      <sql:transaction dataSource="${db}">
        <sql:update>
          INSERT INTO usuarios (documento,nombres,apellidos,email,password_hash,telefono,programa,activo)
          VALUES (?,?,?,?,SHA2(?,256),?,?,1)
          <sql:param value="${param.documento}"/>
          <sql:param value="${param.nombres}"/>
          <sql:param value="${param.apellidos}"/>
          <sql:param value="${param.email}"/>
          <sql:param value="${param.password}"/>
          <sql:param value="${param.telefono}"/>
          <sql:param value="${param.programa}"/>
        </sql:update>
        <sql:query var="nuevoUsuario">SELECT LAST_INSERT_ID() AS id</sql:query>
        <c:forEach items="${param.roles}" var="rolId">
          <sql:update>
            INSERT INTO usuario_rol (usuario_id,rol_id) VALUES (?,?)
            <sql:param value="${nuevoUsuario.rows[0].id}"/>
            <sql:param value="${rolId}"/>
          </sql:update>
        </c:forEach>
      </sql:transaction>
      <c:redirect url="/comite/usuarios.jsp"><c:param name="ok" value="Usuario creado correctamente"/></c:redirect>
    </c:catch>
    <c:if test="${not empty err}"><c:redirect url="/comite/usuarios.jsp"><c:param name="error" value="No se pudo crear el usuario (documento o email duplicado). Intente de nuevo."/></c:redirect></c:if>
  </c:if>

  <%-- ACCIÓN: Editar usuario --%>
  <c:if test="${param.accion == 'editar'}">
    <c:catch var="err">
      <sql:transaction dataSource="${db}">
        <sql:update>
          UPDATE usuarios SET documento=?,nombres=?,apellidos=?,email=?,telefono=?,programa=?,activo=? WHERE id=?
          <sql:param value="${param.documento}"/>
          <sql:param value="${param.nombres}"/>
          <sql:param value="${param.apellidos}"/>
          <sql:param value="${param.email}"/>
          <sql:param value="${param.telefono}"/>
          <sql:param value="${param.programa}"/>
          <sql:param value="${param.activo}"/>
          <sql:param value="${param.id}"/>
        </sql:update>
        <c:if test="${not empty param.password}">
          <sql:update>
            UPDATE usuarios SET password_hash=SHA2(?,256) WHERE id=?
            <sql:param value="${param.password}"/>
            <sql:param value="${param.id}"/>
          </sql:update>
        </c:if>
        <sql:update>
          DELETE FROM usuario_rol WHERE usuario_id=?
          <sql:param value="${param.id}"/>
        </sql:update>
        <c:forEach items="${param.roles}" var="rolId">
          <sql:update>
            INSERT INTO usuario_rol (usuario_id,rol_id) VALUES (?,?)
            <sql:param value="${param.id}"/>
            <sql:param value="${rolId}"/>
          </sql:update>
        </c:forEach>
      </sql:transaction>
      <c:redirect url="/comite/usuarios.jsp"><c:param name="ok" value="Usuario actualizado"/></c:redirect>
    </c:catch>
    <c:if test="${not empty err}"><c:redirect url="/comite/usuarios.jsp"><c:param name="error" value="No se pudo actualizar el usuario (duplicado o datos inválidos)."/></c:redirect></c:if>
  </c:if>

  <%-- ACCIÓN: Eliminar usuario (no permite auto-eliminación; FK se informa claro) --%>
  <c:if test="${param.accion == 'eliminar'}">
    <c:if test="${param.id == sessionScope.usuario_id}">
      <c:redirect url="/comite/usuarios.jsp"><c:param name="error" value="No puede eliminar su propio usuario."/></c:redirect>
    </c:if>
    <c:catch var="err">
      <sql:update dataSource="${db}">
        DELETE FROM usuarios WHERE id=?
        <sql:param value="${param.id}"/>
      </sql:update>
      <c:redirect url="/comite/usuarios.jsp"><c:param name="ok" value="Usuario eliminado"/></c:redirect>
    </c:catch>
    <c:if test="${not empty err}"><c:redirect url="/comite/usuarios.jsp"><c:param name="error" value="No se pudo eliminar: el usuario tiene proyectos o propuestas vinculadas."/></c:redirect></c:if>
  </c:if>
</c:if>

<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}"/>
<c:set var="limite" value="${empty param.limite ? 10 : param.limite}"/>
<c:set var="offset" value="${(pagina - 1) * limite}"/>
<c:set var="q" value="${param.q}"/>
<c:set var="filtroRol" value="${param.filtroRol}"/>

<sql:query dataSource="${db}" var="todosLosRoles">SELECT * FROM roles ORDER BY id</sql:query>

<c:choose>
  <c:when test="${not empty q or not empty filtroRol}">
    <sql:query dataSource="${db}" var="conteo">
      SELECT COUNT(DISTINCT u.id) AS total FROM usuarios u
      LEFT JOIN usuario_rol ur ON u.id = ur.usuario_id
      LEFT JOIN roles r ON ur.rol_id = r.id
      WHERE (u.documento LIKE CONCAT('%',?,'%') OR u.nombres LIKE CONCAT('%',?,'%') OR u.apellidos LIKE CONCAT('%',?,'%') OR u.email LIKE CONCAT('%',?,'%'))
        AND (? = '' OR r.id = ?)
      <sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/>
      <sql:param value="${filtroRol}"/><sql:param value="${filtroRol}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="usuarios">
      SELECT u.*, GROUP_CONCAT(r.nombre) AS roles FROM usuarios u
      LEFT JOIN usuario_rol ur ON u.id = ur.usuario_id
      LEFT JOIN roles r ON ur.rol_id = r.id
      WHERE (u.documento LIKE CONCAT('%',?,'%') OR u.nombres LIKE CONCAT('%',?,'%') OR u.apellidos LIKE CONCAT('%',?,'%') OR u.email LIKE CONCAT('%',?,'%'))
        AND (? = '' OR r.id = ?)
      GROUP BY u.id ORDER BY u.fecha_registro DESC LIMIT ${limite} OFFSET ${offset}
      <sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/><sql:param value="${q}"/>
      <sql:param value="${filtroRol}"/><sql:param value="${filtroRol}"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteo">SELECT COUNT(*) AS total FROM usuarios</sql:query>
    <sql:query dataSource="${db}" var="usuarios">
      SELECT u.*, GROUP_CONCAT(r.nombre) AS roles FROM usuarios u
      LEFT JOIN usuario_rol ur ON u.id = ur.usuario_id
      LEFT JOIN roles r ON ur.rol_id = r.id
      GROUP BY u.id ORDER BY u.fecha_registro DESC LIMIT ${limite} OFFSET ${offset}
    </sql:query>
  </c:otherwise>
</c:choose>
<c:set var="total" value="${conteo.rows[0].total}"/>
<c:set var="totalPaginas" value="${(total + limite - 1) / limite}"/>

<c:if test="${param.accion == 'verEditar' and not empty param.id and esAdmin}">
  <sql:query dataSource="${db}" var="usuarioEdit">
    SELECT u.*, GROUP_CONCAT(ur.rol_id) AS rol_ids FROM usuarios u
    LEFT JOIN usuario_rol ur ON u.id = ur.usuario_id
    WHERE u.id = ? GROUP BY u.id
    <sql:param value="${param.id}"/>
  </sql:query>
</c:if>

<!DOCTYPE html>
<html lang="es">
<head><title>Gestión de [USUARIOS] - SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
<body>
<%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
<div class="main-wrapper">
  <%@ include file="/WEB-INF/jspf/topbar.jspf" %>
  <div class="main-content">
    <c:if test="${not empty param.error}"><div class="alert alert-danger alert-dismissible fade show">${param.error}<button class="btn-close" data-bs-dismiss="alert"></button></div></c:if>
    <c:if test="${not empty param.ok}"><div class="alert alert-success alert-dismissible fade show">${param.ok}<button class="btn-close" data-bs-dismiss="alert"></button></div></c:if>

    <div class="row g-4">
      <div class="col-12">
        <div class="card-sigrado">
          <div class="card-header-custom d-flex justify-content-between align-items-center">
            <h5 class="card-title-institucional mb-0">
              <c:choose>
                <c:when test="${param.accion == 'verEditar' and esAdmin}">Editar Usuario</c:when>
                <c:when test="${esAdmin}">Crear Nuevo Usuario</c:when>
                <c:otherwise>Usuarios (Solo Consulta)</c:otherwise>
              </c:choose>
            </h5>
          </div>
          <c:if test="${esAdmin}">
            <div class="card-body">
              <form method="post" class="row g-3" action="usuarios.jsp">
                <c:choose>
                  <c:when test="${param.accion == 'verEditar'}">
                    <input type="hidden" name="accion" value="editar"/>
                    <input type="hidden" name="id" value="${usuarioEdit.rows[0].id}"/>
                  </c:when>
                  <c:otherwise><input type="hidden" name="accion" value="crear"/></c:otherwise>
                </c:choose>
                <div class="col-md-4"><label class="form-label">Documento *</label><input type="text" name="documento" class="form-control" value="${usuarioEdit.rows[0].documento}" required></div>
                <div class="col-md-4"><label class="form-label">Nombres *</label><input type="text" name="nombres" class="form-control" value="${usuarioEdit.rows[0].nombres}" required></div>
                <div class="col-md-4"><label class="form-label">Apellidos *</label><input type="text" name="apellidos" class="form-control" value="${usuarioEdit.rows[0].apellidos}" required></div>
                <div class="col-md-6"><label class="form-label">Email *</label><input type="email" name="email" class="form-control" value="${usuarioEdit.rows[0].email}" required></div>
                <div class="col-md-3"><label class="form-label">Teléfono</label><input type="text" name="telefono" class="form-control" value="${usuarioEdit.rows[0].telefono}"></div>
                <div class="col-md-3"><label class="form-label">Programa</label><input type="text" name="programa" class="form-control" value="${usuarioEdit.rows[0].programa}"></div>
                <div class="col-md-3">
                  <label class="form-label"><c:choose><c:when test="${param.accion=='verEditar'}">Nueva contraseña</c:when><c:otherwise>Contraseña *</c:otherwise></c:choose></label>
                  <input type="password" name="password" class="form-control" ${param.accion!='verEditar' ? 'required' : ''} placeholder="${param.accion=='verEditar' ? 'Deje vacío para no cambiar' : ''}">
                </div>
                <div class="col-md-3"><label class="form-label">Estado</label>
                  <select name="activo" class="form-select"><option value="1" ${usuarioEdit.rows[0].activo?'selected':''}>Activo</option><option value="0" ${not usuarioEdit.rows[0].activo?'selected':''}>Inactivo</option></select>
                </div>
                <div class="col-md-6"><label class="form-label">Roles *</label>
                  <select name="roles" class="form-select" multiple required size="4">
                    <c:forEach items="${todosLosRoles.rows}" var="r">
                      <option value="${r.id}" ${fn:contains(usuarioEdit.rows[0].rol_ids,r.id)?'selected':''}>${r.nombre}</option>
                    </c:forEach>
                  </select>
                  <div class="form-text">Ctrl+Click para múltiples roles</div>
                </div>
                <div class="col-12 d-flex gap-2">
                  <button type="submit" class="btn btn-uts"><c:choose><c:when test="${param.accion=='verEditar'}">Actualizar</c:when><c:otherwise>Crear</c:otherwise></c:choose></button>
                  <c:if test="${param.accion=='verEditar'}"><a href="usuarios.jsp" class="btn btn-outline-secondary">Cancelar</a></c:if>
                </div>
              </form>
            </div>
          </c:if>
        </div>
      </div>
    </div>

    <div class="row g-4 mt-1">
      <div class="col-12">
        <div class="card-sigrado">
          <div class="card-header-custom d-flex justify-content-between align-items-center flex-wrap gap-2">
            <h5 class="card-title-institucional mb-0">Listado de Usuarios</h5>
            <form method="get" class="row g-2 align-items-end flex-wrap">
              <div class="col-md-3"><input type="text" name="q" class="form-control" placeholder="Buscar: documento, nombre, email" value="${fn:escapeXml(q)}"></div>
              <div class="col-md-2">
                <select name="filtroRol" class="form-select"><option value="">Todos los roles</option><c:forEach items="${todosLosRoles.rows}" var="r"><option value="${r.id}" ${filtroRol==r.id?'selected':''}>${r.nombre}</option></c:forEach></select>
              </div>
              <div class="col-auto"><button type="submit" class="btn btn-uts btn-sm">Filtrar</button> <a href="usuarios.jsp" class="btn btn-outline-secondary btn-sm">Limpiar</a></div>
            </form>
          </div>
          <div class="card-body p-0">
            <div class="table-responsive">
              <table class="table table-hover mb-0">
                <thead><tr><th>ID</th><th>Documento</th><th>Nombre Completo</th><th>Email</th><th>Roles</th><th>Estado</th><th>Registro</th><th>Acciones</th></tr></thead>
                <tbody>
                  <c:forEach items="${usuarios.rows}" var="u">
                    <tr>
                      <td>${u.id}</td>
                      <td>${u.documento}</td>
                      <td>${u.nombres} ${u.apellidos}</td>
                      <td>${u.email}</td>
                      <td><c:forEach items="${fn:split(u.roles,',')}" var="rol"><span class="badge badge-uts me-1">${rol}</span></c:forEach></td>
                      <td><span class="badge ${u.activo?'bg-success':'bg-secondary'}">${u.activo?'Activo':'Inactivo'}</span></td>
                      <td><small>${fn:substring(u.fecha_registro,0,16)}</small></td>
                      <td>
                        <c:if test="${esAdmin}">
                          <a href="usuarios.jsp?accion=verEditar&id=${u.id}" class="btn-action btn-ver" title="Editar"><i class="fas fa-edit"></i></a>
                          <c:if test="${u.id != sessionScope.usuario_id}">
                            <a href="usuarios.jsp?accion=eliminar&id=${u.id}" class="btn-action btn-retirar ms-1" title="Eliminar" onclick="return confirm('¿Eliminar usuario?')"><i class="fas fa-trash"></i></a>
                          </c:if>
                        </c:if>
                        <c:if test="${not esAdmin}">
                          <span class="text-muted small">Solo consulta</span>
                        </c:if>
                      </td>
                    </tr>
                  </c:forEach>
                  <c:if test="${usuarios.rowCount==0}"><tr><td colspan="8" class="empty-state">No hay registros disponibles</td></tr></c:if>
                </tbody>
              </table>
            </div>
            <div class="card-body border-top d-flex justify-content-between align-items-center flex-wrap gap-2">
              <small class="text-muted">Mostrando página ${pagina} de ${totalPaginas} (${total} registros)</small>
              <nav><ul class="pagination pagination-sm mb-0">
                <c:forEach begin="1" end="${totalPaginas}" var="i">
                  <li class="page-item ${i==pagina?'active':''}"><a class="page-link" href="usuarios.jsp?pagina=${i}&limite=${limite}&q=${fn:escapeXml(q)}&filtroRol=${filtroRol}">${i}</a></li>
                </c:forEach>
              </ul></nav>
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