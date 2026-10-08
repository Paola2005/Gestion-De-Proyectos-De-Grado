<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>
<fmt:requestEncoding value="UTF-8"/>

<%-- Solo con sesión. Sin sesión, al login. --%>
<c:if test="${empty sessionScope.usuario_id}">
  <c:redirect url="/login.jsp"><c:param name="error" value="Debe iniciar sesión con su correo institucional"/></c:redirect>
</c:if>
<%-- Con un solo rol no hay nada que elegir. --%>
<sql:query dataSource="${db}" var="misRoles">
  SELECT r.nombre FROM roles r
  INNER JOIN usuario_rol ur ON ur.rol_id = r.id
  WHERE ur.usuario_id = ?
  ORDER BY FIELD(r.nombre,'administrador','comite','docente','estudiante')
  <sql:param value="${sessionScope.usuario_id}"/>
</sql:query>
<c:if test="${misRoles.rowCount <= 1}">
  <c:redirect url="/inicio.jsp"/>
</c:if>

<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>SIGRADO - Elija su rol</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <link href="${pageContext.request.contextPath}/css/estilos.css?v=emerald1" rel="stylesheet">
</head>
<body class="landing-body">
  <nav class="navbar navbar-landing">
    <div class="container">
      <span class="navbar-brand d-flex align-items-center gap-2 mb-0">
        <span class="uts-badge">SIGRADO</span>
        <span class="brand-text">Sistema de Gestión de Trabajos de Grado</span>
      </span>
      <a href="logout.jsp" class="btn btn-uts ms-lg-3">Salir</a>
    </div>
  </nav>

  <main class="container py-5" style="max-width: 860px;">
    <div class="text-center mb-4">
      <h2 class="fw-bold text-dark mt-4">¿Con qué rol desea ingresar?</h2>
      <p class="text-muted">Su usuario <strong><c:out value="${sessionScope.usuario_email}"/></strong> tiene varios roles en el sistema. Elija uno para continuar.</p>
    </div>
    <div class="row g-3 justify-content-center">
      <c:forEach var="r" items="${misRoles.rows}">
        <div class="col-md-6 col-lg-5">
          <div class="landing-card h-100 p-4 text-center">
            <div class="icon-wrapper icon-green mb-3 mx-auto" style="width:56px;height:56px;display:flex;align-items:center;justify-content:center;">
              <c:choose>
                <c:when test="${r.nombre == 'administrador'}"><i class="fas fa-users-cog"></i></c:when>
                <c:when test="${r.nombre == 'comite'}"><i class="fas fa-clipboard-check"></i></c:when>
                <c:when test="${r.nombre == 'docente'}"><i class="fas fa-chalkboard-teacher"></i></c:when>
                <c:otherwise><i class="fas fa-graduation-cap"></i></c:otherwise>
              </c:choose>
            </div>
            <h5 class="text-capitalize"><c:out value="${r.nombre}"/></h5>
            <p class="small text-muted">
              <c:choose>
                <c:when test="${r.nombre == 'administrador'}">Gestiona usuarios, periodos, formatos y proyectos.</c:when>
                <c:when test="${r.nombre == 'comite'}">Aprueba ideas y proyectos, asigna tribunales y cierra fases.</c:when>
                <c:when test="${r.nombre == 'docente'}">Dirige y evalúa proyectos en las fases 2 a 5.</c:when>
                <c:otherwise>Radica su proyecto y consulta su avance por fases.</c:otherwise>
              </c:choose>
            </p>
            <a href="cambiar_rol.jsp?rol=${r.nombre}" class="btn btn-uts w-100">Ingresar como <span class="text-capitalize">${r.nombre}</span></a>
          </div>
        </div>
      </c:forEach>
    </div>
  </main>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
