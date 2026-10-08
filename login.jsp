<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>

<c:if test="${not empty sessionScope.usuario_id}">
  <c:redirect url="/inicio.jsp"/>
</c:if>

<c:if test="${not empty param.email and not empty param.password}">
  <c:catch var="errLogin">
    <sql:query dataSource="${db}" var="usr">
      SELECT u.id, u.documento, u.nombres, u.apellidos, u.email, u.activo,
             GROUP_CONCAT(r.nombre) AS roles
      FROM usuarios u
      LEFT JOIN usuario_rol ur ON u.id = ur.usuario_id
      LEFT JOIN roles r ON ur.rol_id = r.id
      WHERE (u.email = ? OR u.documento = ?) AND u.password_hash = SHA2(?, 256)
      GROUP BY u.id
      <sql:param value="${param.email}"/>
      <sql:param value="${param.email}"/>
      <sql:param value="${param.password}"/>
    </sql:query>
    <c:choose>
      <c:when test="${usr.rowCount == 1}">
        <c:if test="${!usr.rows[0].activo}">
          <c:redirect url="/login.jsp"><c:param name="error" value="Usuario inactivo. Contacte al Administrador."/></c:redirect>
        </c:if>
        <%-- Los roles se leen siempre de la base de datos; sin roles no hay acceso --%>
        <c:if test="${empty usr.rows[0].roles}">
          <c:redirect url="/login.jsp"><c:param name="error" value="Su usuario no tiene roles asignados. Contacte al Administrador."/></c:redirect>
        </c:if>
        <c:set var="usuario_id" value="${usr.rows[0].id}" scope="session"/>
        <c:set var="usuario_nombres" value="${usr.rows[0].nombres}" scope="session"/>
        <c:set var="usuario_apellidos" value="${usr.rows[0].apellidos}" scope="session"/>
        <c:set var="usuario_email" value="${usr.rows[0].email}" scope="session"/>
        <c:set var="usuario_documento" value="${usr.rows[0].documento}" scope="session"/>
        <c:set var="roles" value="${usr.rows[0].roles}" scope="session"/>
        <c:set var="rol_activo" value="" scope="session"/>
        <c:choose>
          <c:when test="${fn:contains(usr.rows[0].roles,'comite')}"><c:set var="rol_principal" value="Comité" scope="session"/></c:when>
          <c:when test="${fn:contains(usr.rows[0].roles,'administrador')}"><c:set var="rol_principal" value="Administrador" scope="session"/></c:when>
          <c:when test="${fn:contains(usr.rows[0].roles,'docente')}"><c:set var="rol_principal" value="Docente" scope="session"/></c:when>
          <c:otherwise><c:set var="rol_principal" value="Estudiante" scope="session"/></c:otherwise>
        </c:choose>
        <%-- Un solo rol: entra directo a su inicio. Varios roles: elige con cuál entrar. --%>
        <sql:query dataSource="${db}" var="nroles">
          SELECT COUNT(*) AS n FROM usuario_rol WHERE usuario_id = ?
          <sql:param value="${usr.rows[0].id}"/>
        </sql:query>
        <c:choose>
          <c:when test="${nroles.rows[0].n > 1}">
            <c:redirect url="/elegir_rol.jsp"/>
          </c:when>
          <c:otherwise>
            <c:choose>
              <c:when test="${fn:contains(usr.rows[0].roles,'comite')}"><c:set var="rol_activo" value="comite" scope="session"/></c:when>
              <c:when test="${fn:contains(usr.rows[0].roles,'administrador')}"><c:set var="rol_activo" value="administrador" scope="session"/></c:when>
              <c:when test="${fn:contains(usr.rows[0].roles,'docente')}"><c:set var="rol_activo" value="docente" scope="session"/></c:when>
              <c:otherwise><c:set var="rol_activo" value="estudiante" scope="session"/></c:otherwise>
            </c:choose>
            <c:redirect url="/inicio.jsp"/>
          </c:otherwise>
        </c:choose>
      </c:when>
      <c:otherwise>
        <c:redirect url="/login.jsp"><c:param name="error" value="Credenciales incorrectas"/></c:redirect>
      </c:otherwise>
    </c:choose>
  </c:catch>
  <c:if test="${not empty errLogin}">
    <c:redirect url="/login.jsp"><c:param name="error" value="Error de conexión. Intente de nuevo."/></c:redirect>
  </c:if>
</c:if>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SIGRADO - Iniciar Sesión</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <link href="${pageContext.request.contextPath}/css/estilos.css?v=emerald1" rel="stylesheet">
  <style>
    /* Ajustes solo del login: tarjeta, demo y responsive */
    .modal-login .demo-accounts .account {
      padding: 0.5rem 0.6rem;
      border-bottom: 1px dashed var(--uts-gray-200);
      margin-bottom: 0;
    }
    .modal-login .demo-accounts .account:last-child {
      border-bottom: none;
    }
    .modal-login .demo-accounts .demo-name {
      display: block;
      color: #495057;
    }
    .modal-login .demo-accounts .demo-mail {
      display: inline-block;
      margin-top: 0.15rem;
      cursor: pointer;
      overflow-wrap: anywhere;
      word-break: break-word;
    }
    .modal-login .demo-accounts .demo-mail:hover {
      border-color: var(--uts-primary);
    }
    @media (max-width: 575.98px) {
      .modal-login .modal-body {
        padding: 1.25rem;
      }
    }
  </style>
</head>
<body style="background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%); min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 2rem;">
  <a href="index.jsp" class="position-fixed top-0 start-0 m-3 text-decoration-none fw-bold bg-white border rounded-pill px-3 py-2 shadow-sm text-dark" style="z-index: 1050;">
    <i class="fas fa-arrow-left me-1"></i> Volver al inicio
  </a>

  <div class="card shadow border-0 modal-login" style="max-width: 420px; width: 100%; border-radius: 20px; overflow: hidden;">
    <div class="modal-header-custom">
      <div class="icon-university"><i class="fas fa-university"></i></div>
      <h4>SIGRADO</h4>
      <p>Sistema de Gestión de Trabajos de Grado - UTS</p>
    </div>
    <div class="modal-body">
      <c:if test="${not empty param.ok}">
        <div class="alert alert-success alert-dismissible fade show small py-2" role="alert">
          <i class="fas fa-check-circle me-1"></i> <c:out value="${param.ok}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>
      <c:if test="${not empty param.error}">
        <div class="alert alert-danger alert-dismissible fade show small py-2" role="alert">
          <i class="fas fa-exclamation-circle me-1"></i> <c:out value="${param.error}"/>
          <button type="button" class="btn-close py-2" data-bs-dismiss="alert"></button>
        </div>
      </c:if>

      <form method="post" action="login.jsp">
        <div class="mb-3">
          <label class="form-label">Correo institucional</label>
          <div class="input-group">
            <span class="input-group-text"><i class="fas fa-envelope text-muted"></i></span>
            <input type="email" id="correoInput" name="email" class="form-control" required placeholder="ej: usuario@uts.edu.co" autocomplete="username">
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label">Contraseña</label>
          <div class="input-group">
            <span class="input-group-text"><i class="fas fa-lock text-muted"></i></span>
            <input type="password" name="password" class="form-control" required placeholder="••••••" autocomplete="current-password">
          </div>
        </div>
        <button type="submit" class="btn btn-login w-100">
          <i class="fas fa-sign-in-alt me-1"></i> Ingresar al Sistema
        </button>
      </form>

      <%-- Cuentas de demostración con datos reales de la base de datos (solo lectura) --%>
      <sql:query dataSource="${db}" var="demoComite">
        SELECT u.nombres, u.apellidos, u.email FROM usuarios u
        INNER JOIN usuario_rol ur ON ur.usuario_id = u.id
        INNER JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'comite'
        WHERE u.activo = 1 ORDER BY u.id LIMIT 1
      </sql:query>
      <sql:query dataSource="${db}" var="demoAdmin">
        SELECT u.nombres, u.apellidos, u.email FROM usuarios u
        INNER JOIN usuario_rol ur ON ur.usuario_id = u.id
        INNER JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'administrador'
        WHERE u.activo = 1 ORDER BY u.id LIMIT 1
      </sql:query>
      <sql:query dataSource="${db}" var="demoDocentes">
        SELECT u.nombres, u.apellidos, u.email FROM usuarios u
        INNER JOIN usuario_rol ur ON ur.usuario_id = u.id
        INNER JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'docente'
        WHERE u.activo = 1 GROUP BY u.id ORDER BY u.id LIMIT 2
      </sql:query>
      <sql:query dataSource="${db}" var="demoEst">
        SELECT u.nombres, u.apellidos, u.email FROM usuarios u
        INNER JOIN usuario_rol ur ON ur.usuario_id = u.id
        INNER JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'estudiante'
        WHERE u.activo = 1 ORDER BY u.id LIMIT 1
      </sql:query>
      <div class="demo-accounts">
        <div class="title"><i class="fas fa-users me-1"></i> Cuentas de Demostración (Clave: <code>123456</code>):</div>
        <c:forEach var="u" items="${demoComite.rows}">
          <div class="account"><strong>Comité:</strong><span class="demo-name">${u.nombres} ${u.apellidos}</span><code class="demo-mail" data-email="${u.email}" title="Pulsar para copiar al campo de correo">${u.email}</code></div>
        </c:forEach>
        <c:forEach var="u" items="${demoAdmin.rows}">
          <div class="account"><strong>Administrador:</strong><span class="demo-name">${u.nombres} ${u.apellidos}</span><code class="demo-mail" data-email="${u.email}" title="Pulsar para copiar al campo de correo">${u.email}</code></div>
        </c:forEach>
        <c:forEach var="u" items="${demoDocentes.rows}">
          <div class="account"><strong>Docente:</strong><span class="demo-name">${u.nombres} ${u.apellidos}</span><code class="demo-mail" data-email="${u.email}" title="Pulsar para copiar al campo de correo">${u.email}</code></div>
        </c:forEach>
        <c:forEach var="u" items="${demoEst.rows}">
          <div class="account"><strong>Estudiante:</strong><span class="demo-name">${u.nombres} ${u.apellidos}</span><code class="demo-mail" data-email="${u.email}" title="Pulsar para copiar al campo de correo">${u.email}</code></div>
        </c:forEach>
      </div>
    </div>
  </div>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
  <script>
    // Pulsar un correo de demostración lo copia al campo de correo
    document.addEventListener('DOMContentLoaded', function() {
      var campo = document.getElementById('correoInput');
      document.querySelectorAll('.demo-mail').forEach(function(el) {
        el.addEventListener('click', function() {
          if (campo) { campo.value = this.dataset.email || this.textContent.trim(); campo.focus(); }
        });
      });
    });
  </script>
</body>
</html>