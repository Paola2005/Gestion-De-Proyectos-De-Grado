<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ include file="/WEB-INF/jspf/guard.jspf" %>
<sql:query dataSource="${db}" var="miTel">
  SELECT telefono, programa FROM usuarios WHERE id = ?
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>
<c:set var="telActual" value="${miTel.rowCount > 0 ? miTel.rows[0].telefono : ''}"/>
<c:set var="progActual" value="${miTel.rowCount > 0 and not empty miTel.rows[0].programa ? miTel.rows[0].programa : 'Ingeniería de Sistemas'}"/>
<c:if test="${param.accion == 'actualizar'}">
  <c:catch var="errUpd">
    <sql:update dataSource="${db}">
      UPDATE usuarios SET nombres=?, apellidos=?, telefono=? WHERE id=?
      <sql:param value="${param.nombres}"/><sql:param value="${param.apellidos}"/>
      <sql:param value="${param.telefono}"/><sql:param value="${sessionScope.usuario_id}"/>
    </sql:update>
    <c:set var="usuario_nombres" value="${param.nombres}" scope="session"/>
    <c:set var="usuario_apellidos" value="${param.apellidos}" scope="session"/>
    <c:redirect url="/perfil.jsp"><c:param name="ok" value="Perfil actualizado correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errUpd}"><c:redirect url="/perfil.jsp"><c:param name="error" value="Error al actualizar el perfil. Intente de nuevo."/></c:redirect></c:if>
</c:if>
<c:if test="${param.accion == 'clave'}">
  <c:catch var="errClave">
    <c:if test="${param.clave1 != param.clave2}">
      <c:redirect url="/perfil.jsp"><c:param name="error" value="Las contraseñas no coinciden"/></c:redirect>
    </c:if>
    <sql:update dataSource="${db}">
      UPDATE usuarios SET password_hash=SHA2(?,256) WHERE id=?
      <sql:param value="${param.clave1}"/><sql:param value="${sessionScope.usuario_id}"/>
    </sql:update>
    <c:redirect url="/perfil.jsp"><c:param name="ok" value="Contraseña actualizada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errClave}"><c:redirect url="/perfil.jsp"><c:param name="error" value="Error al cambiar la contraseña. Intente de nuevo."/></c:redirect></c:if>
</c:if>

<!DOCTYPE html>
<html lang="es">
<head><title>Mi Perfil - SIGRADO</title><%@ include file="/WEB-INF/jspf/header.jspf" %></head>
<body>
<%@ include file="/WEB-INF/jspf/sidebar.jspf" %>
<main class="main">
  <header class="topbar">
    <div class="welcome">Mi <span class="text-uts">[PERFIL]</span></div>
    <div class="user-info">
      <div class="user-name">${sessionScope.usuario_nombres} ${sessionScope.usuario_apellidos}</div>
      <div class="user-rol">${sessionScope.rol_principal}</div>
    </div>
  </header>
  <div class="container-fluid py-4 px-4">
    <div class="row g-4">
      <div class="col-lg-4">
        <div class="card-uts text-center p-4">
          <div class="avatar mx-auto mb-3" style="width:100px;height:100px;font-size:2.5rem">
            ${fn:substring(sessionScope.usuario_nombres,0,1)}${fn:substring(sessionScope.usuario_apellidos,0,1)}
          </div>
          <h4 class="mb-1">${sessionScope.usuario_nombres} ${sessionScope.usuario_apellidos}</h4>
          <div class="text-muted mb-3">${sessionScope.rol_principal}</div>
          <div class="d-flex flex-wrap justify-content-center gap-1 mb-3">
            <c:forEach var="rol" items="${fn:split(sessionScope.roles,',')}">
              <span class="badge badge-uts">${rol}</span>
            </c:forEach>
          </div>
        </div>
      </div>
      <div class="col-lg-8">
        <div class="card-uts p-4 mb-4">
          <h5 class="mb-3">Datos Personales</h5>
          <form method="post" class="row g-3" action="perfil.jsp">
            <input type="hidden" name="accion" value="actualizar"/>
            <div class="col-md-6"><label class="form-label">Nombres *</label><input type="text" name="nombres" class="form-control" value="${sessionScope.usuario_nombres}" required></div>
            <div class="col-md-6"><label class="form-label">Apellidos *</label><input type="text" name="apellidos" class="form-control" value="${sessionScope.usuario_apellidos}" required></div>
            <div class="col-md-6"><label class="form-label">Documento</label><input type="text" class="form-control" value="${sessionScope.usuario_documento}" readonly></div>
            <div class="col-md-6"><label class="form-label">Email</label><input type="email" class="form-control" value="${sessionScope.usuario_email}" readonly></div>
            <div class="col-md-6"><label class="form-label">Teléfono</label><input type="text" name="telefono" class="form-control" value="${telActual}"></div>
            <div class="col-md-6"><label class="form-label">Programa</label><input type="text" class="form-control" value="${progActual}" readonly></div>
            <div class="col-12"><button type="submit" class="btn btn-uts">Guardar Cambios</button></div>
          </form>
        </div>
        <div class="card-uts p-4">
          <h5 class="mb-3">Cambiar Contraseña</h5>
          <form method="post" class="row g-3" action="perfil.jsp">
            <input type="hidden" name="accion" value="clave"/>
            <div class="col-md-6"><label class="form-label">Nueva contraseña *</label><input type="password" name="clave1" class="form-control" required autocomplete="new-password"></div>
            <div class="col-md-6"><label class="form-label">Confirmar contraseña *</label><input type="password" name="clave2" class="form-control" required autocomplete="new-password"></div>
            <div class="col-12"><button type="submit" class="btn btn-outline-uts">Actualizar Contraseña</button></div>
          </form>
        </div>
      </div>
    </div>
  </div>
  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</main>
</body>
</html>