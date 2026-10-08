<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%-- Cerrar sesión: elimina todos los atributos de autenticación y destruye la sesión.
     Vuelve a la página de aterrizaje pública. --%>
<c:remove var="usuario_id" scope="session"/>
<c:remove var="usuario_nombres" scope="session"/>
<c:remove var="usuario_apellidos" scope="session"/>
<c:remove var="usuario_email" scope="session"/>
<c:remove var="usuario_documento" scope="session"/>
<c:remove var="roles" scope="session"/>
<c:remove var="rol_principal" scope="session"/>
<c:remove var="rol_activo" scope="session"/>
<c:catch var="errInv">${session.invalidate()}</c:catch>
<c:redirect url="/index.jsp"><c:param name="ok" value="Sesión cerrada correctamente"/></c:redirect>
