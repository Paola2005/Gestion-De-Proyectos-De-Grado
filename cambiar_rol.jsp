<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<fmt:requestEncoding value="UTF-8"/>

<%-- Solo con sesión; la validación del rol se hace contra la base de datos vía sesión. --%>
<c:if test="${empty sessionScope.usuario_id}">
  <c:redirect url="/login.jsp"><c:param name="error" value="Debe iniciar sesión con su correo institucional"/></c:redirect>
</c:if>

<c:set var="targetRol" value="${param.rol}"/>
<c:set var="userRoles" value="${sessionScope.roles}"/>

<%-- Solo permite roles que el usuario realmente tiene (sin roles fijos en el código). --%>
<c:choose>
  <c:when test="${targetRol == 'administrador' and fn:contains(userRoles, 'administrador')}">
    <c:set var="rol_principal" value="Administrador" scope="session"/>
    <c:set var="rol_activo" value="administrador" scope="session"/>
  </c:when>
  <c:when test="${targetRol == 'comite' and fn:contains(userRoles, 'comite')}">
    <c:set var="rol_principal" value="Comité" scope="session"/>
    <c:set var="rol_activo" value="comite" scope="session"/>
  </c:when>
  <c:when test="${targetRol == 'docente' and fn:contains(userRoles, 'docente')}">
    <c:set var="rol_principal" value="Docente" scope="session"/>
    <c:set var="rol_activo" value="docente" scope="session"/>
  </c:when>
  <c:when test="${targetRol == 'estudiante' and fn:contains(userRoles, 'estudiante')}">
    <c:set var="rol_principal" value="Estudiante" scope="session"/>
    <c:set var="rol_activo" value="estudiante" scope="session"/>
  </c:when>
  <c:otherwise>
    <c:redirect url="/elegir_rol.jsp"><c:param name="error" value="Rol no válido para su usuario"/></c:redirect>
  </c:otherwise>
</c:choose>

<c:redirect url="/inicio.jsp"/>
