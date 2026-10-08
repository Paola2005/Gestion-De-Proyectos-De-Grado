<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/guardComite.jspf" %>

<%-- Procesamiento: Evaluación de Comité en FASE 1 (valida turno F1·Comité) --%>
<c:if test="${param.accion == 'responder_fase1' and not empty param.proyecto_id}">
  <c:catch var="errFase1">
    <sql:query dataSource="${db}" var="turnoF1">
      SELECT fase, responsable, estado, tipo_nivel FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoF1.rowCount == 0 or turnoF1.rows[0].fase != 1 or turnoF1.rows[0].responsable != 'comite' or turnoF1.rows[0].estado != 'En curso'}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El proyecto ya no está en su turno (Fase 1 · Comité)."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <%-- Rechazado solo pide acta, fecha y comentarios; Correcciones y Aprobado también exigen acta+fecha --%>
    <c:if test="${empty param.acta_numero or empty param.acta_fecha}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Toda respuesta debe indicar acta y fecha."/></c:redirect>
    </c:if>
    <c:if test="${param.decision_fase1 == 'Aprobado' and (empty param.director_id or empty param.evaluador_id or empty param.codigo_modalidad or empty param.acta_numero or empty param.acta_fecha)}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Para aprobar Fase 1 debe indicar acta, fecha, código de modalidad, director y evaluador."/></c:redirect>
    </c:if>
    <c:if test="${param.decision_fase1 == 'Aprobado' and param.director_id == param.evaluador_id}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El director y el evaluador deben ser docentes diferentes."/></c:redirect>
    </c:if>
    <%-- Código de modalidad: 65 tecnológico, 125 profesional (+ año + consecutivo). Valida prefijo según nivel y formato https:no, solo código --%>
    <c:if test="${param.decision_fase1 == 'Aprobado' and turnoF1.rows[0].tipo_nivel == 'Profesional' and not fn:startsWith(param.codigo_modalidad,'125-')}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Nivel Profesional exige código de modalidad 125-año-consecutivo (ej: 125-2026-001)."/></c:redirect>
    </c:if>
    <c:if test="${param.decision_fase1 == 'Aprobado' and turnoF1.rows[0].tipo_nivel == 'Tecnologico' and not fn:startsWith(param.codigo_modalidad,'65-')}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Nivel Tecnológico exige código de modalidad 65-año-consecutivo (ej: 65-2026-001)."/></c:redirect>
    </c:if>
    <c:if test="${param.decision_fase1 == 'Aprobado'}">
      <sql:query dataSource="${db}" var="dupCod">
        SELECT COUNT(*) AS c FROM proyectos WHERE codigo_modalidad = ? AND id != ?
        <sql:param value="${param.codigo_modalidad}"/><sql:param value="${param.proyecto_id}"/>
      </sql:query>
      <c:if test="${dupCod.rows[0].c > 0}">
        <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El código de modalidad ya está asignado a otro proyecto."/></c:redirect>
      </c:if>
      <%-- La idea de un estudiante solo se aprueba si tiene la URL del pago --%>
      <sql:query dataSource="${db}" var="pagoOk">
        SELECT COUNT(*) AS c FROM documentos
        WHERE proyecto_id = ? AND tipo = 'SoportePago' AND url LIKE 'https://%'
        <sql:param value="${param.proyecto_id}"/>
      </sql:query>
      <c:if test="${pagoOk.rows[0].c == 0}">
        <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="No se puede aprobar Fase 1: el proyecto no tiene URL de comprobante de pago (https://)."/></c:redirect>
      </c:if>
    </c:if>
    <%-- Ronda y versión evaluada (SoportePago) para el registro de respuesta --%>
    <sql:query dataSource="${db}" var="rondaF1">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 1
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verF1">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'SoportePago'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <c:choose>
        <c:when test="${param.decision_fase1 == 'Aprobado'}">
          <%-- Al aprobar Fase 1: tribunal de 2 (director + evaluador, sin codirector), pasa a Fase 2 · Estudiante --%>
          <sql:update>
            UPDATE proyectos
            SET fase = 2,
                responsable = 'estudiante',
                estado = 'En curso',
                codigo_modalidad = ?,
                director_id = ?,
                evaluador_id = ?,
                codirector_id = NULL
            WHERE id = ? AND fase = 1 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.codigo_modalidad}"/>
            <sql:param value="${param.director_id}"/>
            <sql:param value="${param.evaluador_id}"/>
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario, codigo_modalidad, director_id, evaluador_id, codirector_id)
            VALUES (?, 1, ?, ?, ?, 'comite', 'Aprobado', ?, ?, ?, ?, ?, ?, NULL)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${rondaF1.rows[0].sig}"/>
            <sql:param value="${verF1.rows[0].mv}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.acta_fecha}"/>
            <sql:param value="${param.comentarios}"/>
            <sql:param value="${param.codigo_modalidad}"/>
            <sql:param value="${param.director_id}"/>
            <sql:param value="${param.evaluador_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Aprobación Comité Fase 1 y Asignación de Tribunal', 1, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="Aprobado. Se asignó tribunal e inicia Fase 2."/>
          </sql:update>
          <sql:update>
            INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
            VALUES (?, 'Aprobación Fase 1', 'proyectos', ?)
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="Comité aprobó Fase 1 para proyecto ID ${param.proyecto_id}"/>
          </sql:update>
        </c:when>
        <c:when test="${param.decision_fase1 == 'Correcciones'}">
          <sql:update>
            UPDATE proyectos SET fase = 1, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 1 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario)
            VALUES (?, 1, ?, ?, ?, 'comite', 'Correcciones', ?, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${rondaF1.rows[0].sig}"/>
            <sql:param value="${verF1.rows[0].mv}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.acta_fecha}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Correcciones Comité Fase 1', 1, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
        </c:when>
        <c:otherwise>
          <sql:update>
            UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario)
            VALUES (?, 1, ?, ?, ?, 'comite', 'Rechazado', ?, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${rondaF1.rows[0].sig}"/>
            <sql:param value="${verF1.rows[0].mv}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.acta_fecha}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Rechazo de Proyecto Fase 1', 1, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
          <sql:update>
            INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
            VALUES (?, 'Rechazo Fase 1', 'proyectos', ?)
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="Comité rechazó Fase 1 para proyecto ID ${param.proyecto_id}"/>
          </sql:update>
        </c:otherwise>
      </c:choose>
    </sql:transaction>
<c:redirect url="/comite/proyectos.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errFase1}"><c:set var="errorMsg" value="Error en Fase 1. Intente de nuevo."/></c:if>
</c:if>

<%-- Procesamiento: Ratificación de Propuesta por Comité en FASE 3 (valida turno F3·Comité) --%>
<c:if test="${param.accion == 'responder_fase3' and not empty param.proyecto_id}">
  <c:catch var="errFase3">
    <sql:query dataSource="${db}" var="turnoF3">
      SELECT fase, responsable, estado FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoF3.rowCount == 0 or turnoF3.rows[0].fase != 3 or turnoF3.rows[0].responsable != 'comite' or turnoF3.rows[0].estado != 'En curso'}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El proyecto ya no está en su turno (Fase 3 · Comité)."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <c:if test="${empty param.acta_numero or empty param.acta_fecha}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Toda respuesta debe indicar acta y fecha."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaF3">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 3
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verF3">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'Propuesta_FDC124'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <c:choose>
        <c:when test="${param.decision_fase3 == 'Aprobado'}">
          <sql:update>
            UPDATE proyectos 
            SET fase = 4, 
                responsable = 'estudiante',
                estado = 'En curso'
            WHERE id = ? AND fase = 3 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
        </c:when>
        <c:when test="${param.decision_fase3 == 'Correcciones'}">
          <sql:update>
            UPDATE proyectos
            SET fase = 2,
                responsable = 'estudiante',
                estado = 'En curso'
            WHERE id = ? AND fase = 3 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
        </c:when>
        <c:otherwise>
          <sql:update>
            UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
        </c:otherwise>
      </c:choose>

      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario)
        VALUES (?, 3, ?, ?, ?, 'comite', ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${rondaF3.rows[0].sig}"/>
        <sql:param value="${verF3.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.decision_fase3}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentarios}"/>
      </sql:update>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Ratificación Comité Fase 3', 3, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="Comité aprobó propuesta de grado. Inicia Fase 4 (Informe Final). ${param.comentarios}"/>
      </sql:update>

      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Ratificación Comité Fase 3', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Comité emitió resolución ${param.decision_fase3} en Fase 3 para proyecto ID ${param.proyecto_id}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/comite/proyectos.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errFase3}"><c:set var="errorMsg" value="Error en Fase 3. Intente de nuevo."/></c:if>
</c:if>

<%-- Procesamiento: Comité en FASE 5 (Aprobado -> F6·Comité En curso; Aplazado/Correcciones -> F4·Estudiante; Rechazado cierra) --%>
<c:if test="${param.accion == 'responder_fase5' and not empty param.proyecto_id}">
  <c:catch var="errFase5">
    <sql:query dataSource="${db}" var="turnoF5">
      SELECT fase, responsable, estado FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoF5.rowCount == 0 or turnoF5.rows[0].fase != 5 or turnoF5.rows[0].responsable != 'comite' or turnoF5.rows[0].estado != 'En curso'}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El proyecto ya no está en su turno (Fase 5 · Comité)."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <c:if test="${empty param.acta_numero or empty param.acta_fecha}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Toda respuesta debe indicar acta y fecha."/></c:redirect>
    </c:if>
    <c:if test="${(not empty param.informe_fdc125_url and not fn:startsWith(param.informe_fdc125_url,'https://')) or (not empty param.rejilla_fdc129_url and not fn:startsWith(param.rejilla_fdc129_url,'https://'))}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Todo documento es una URL https; no se suben archivos."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaF5">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 5
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verF5">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'Informe_FDC125'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <%-- Aplazado es lo mismo que Correcciones: se guarda como Correcciones (ENUM válido) --%>
    <c:set var="dec5" value="${param.decision_fase5 == 'Aplazado' ? 'Correcciones' : param.decision_fase5}"/>
    <sql:transaction dataSource="${db}">
      <c:choose>
        <c:when test="${param.decision_fase5 == 'Aprobado'}">
          <sql:update>
            UPDATE proyectos SET fase = 6, estado = 'En curso', responsable = 'comite' WHERE id = ? AND fase = 5 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <%-- Registrar Informe F-DC-125 si ingresó URL --%>
          <c:if test="${not empty param.informe_fdc125_url}">
            <sql:query var="maxV5">
              SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos
              WHERE proyecto_id = ? AND tipo = 'Informe_FDC125'
              <sql:param value="${param.proyecto_id}"/>
            </sql:query>
            <sql:update>
              INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
              VALUES (?, 5, 'Informe_FDC125', ?, ?, 'Informe Final F-DC-125 Aprobado', ?)
              <sql:param value="${param.proyecto_id}"/>
              <sql:param value="${maxV5.rows[0].sigVer}"/>
              <sql:param value="${param.informe_fdc125_url}"/>
              <sql:param value="${sessionScope.usuario_id}"/>
            </sql:update>
          </c:if>
          <%-- Registrar Rejilla F-DC-129 si ingresó URL --%>
          <c:if test="${not empty param.rejilla_fdc129_url}">
            <sql:query var="maxVR">
              SELECT COALESCE(MAX(version),0)+1 AS sigVer FROM documentos
              WHERE proyecto_id = ? AND tipo = 'Rejilla_FDC129'
              <sql:param value="${param.proyecto_id}"/>
            </sql:query>
            <sql:update>
              INSERT INTO documentos (proyecto_id, fase, tipo, version, url, nombre_archivo, subido_por)
              VALUES (?, 5, 'Rejilla_FDC129', ?, ?, 'Rejilla F-DC-129 Calificación Final', ?)
              <sql:param value="${param.proyecto_id}"/>
              <sql:param value="${maxVR.rows[0].sigVer}"/>
              <sql:param value="${param.rejilla_fdc129_url}"/>
              <sql:param value="${sessionScope.usuario_id}"/>
            </sql:update>
          </c:if>
        </c:when>
        <c:when test="${param.decision_fase5 == 'Correcciones' or param.decision_fase5 == 'Aplazado'}">
          <%-- Aplazado/Correcciones: vuelve a fase 4, estudiante registra versión nueva --%>
          <sql:update>
            UPDATE proyectos SET fase = 4, responsable = 'estudiante', estado = 'En curso' WHERE id = ? AND fase = 5 AND responsable = 'comite' AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
        </c:when>
        <c:otherwise>
          <sql:update>
            UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
        </c:otherwise>
      </c:choose>

      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario, informe_fdc125_url, rejilla_fdc129_url)
        VALUES (?, 5, ?, ?, ?, 'comite', ?, ?, ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${rondaF5.rows[0].sig}"/>
        <sql:param value="${verF5.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${dec5}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentarios}"/>
        <sql:param value="${param.informe_fdc125_url}"/>
        <sql:param value="${param.rejilla_fdc129_url}"/>
      </sql:update>

      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Dictamen Comité Fase 5', 5, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="Dictamen Fase 5 registrado."/>
      </sql:update>

      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Dictamen Fase 5', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Comité emitió dictamen en Fase 5 para proyecto ID ${param.proyecto_id}. Acta: ${param.acta_numero}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/comite/proyectos.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errFase5}"><c:set var="errorMsg" value="Error en Fase 5. Intente de nuevo."/></c:if>
</c:if>

<%-- Procesamiento: Comité en FASE 6 Cierre (verifica documentos, registra sustentación y Finaliza) --%>
<c:if test="${param.accion == 'responder_fase6' and not empty param.proyecto_id}">
  <c:catch var="errFase6">
    <sql:query dataSource="${db}" var="turnoF6">
      SELECT fase, responsable, estado FROM proyectos WHERE id = ?
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <c:if test="${turnoF6.rowCount == 0 or turnoF6.rows[0].fase != 6 or turnoF6.rows[0].responsable != 'comite' or turnoF6.rows[0].estado != 'En curso'}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="El proyecto ya no está en su turno (Fase 6 · Comité)."/></c:redirect>
    </c:if>
    <%-- Responder sobre un proyecto existente no usa las ventanas de inscripción. --%>
    <c:if test="${empty param.acta_numero or empty param.acta_fecha}">
      <c:redirect url="/comite/proyectos.jsp"><c:param name="error" value="Para cerrar Fase 6 debe indicar acta y fecha."/></c:redirect>
    </c:if>
    <sql:query dataSource="${db}" var="rondaF6">
      SELECT COUNT(*)+1 AS sig FROM respuestas WHERE proyecto_id = ? AND fase = 6
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:query dataSource="${db}" var="verF6">
      SELECT COALESCE(MAX(version),0) AS mv FROM documentos WHERE proyecto_id = ? AND tipo = 'Informe_FDC125'
      <sql:param value="${param.proyecto_id}"/>
    </sql:query>
    <sql:transaction dataSource="${db}">
      <c:choose>
        <c:when test="${param.resultado_sust == 'Aprobado'}">
          <sql:update>
            INSERT INTO sustentaciones (proyecto_id, fecha, hora, lugar_o_enlace, jurados, resultado, numero_acta, observaciones)
            VALUES (?, ?, ?, ?, ?, 'Aprobado', ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${empty param.fecha_sustentacion ? param.acta_fecha : param.fecha_sustentacion}"/>
            <sql:param value="${empty param.hora_sustentacion ? '08:00:00' : param.hora_sustentacion}"/>
            <sql:param value="${empty param.lugar_sustentacion ? 'Auditorio Institucional / Enlace Virtual UTS' : param.lugar_sustentacion}"/>
            <sql:param value="${empty param.jurados_sustentacion ? 'Docentes Jurados de Grado' : param.jurados_sustentacion}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
          <sql:update>
            UPDATE proyectos SET estado = 'Finalizado', responsable = 'comite' WHERE id = ? AND fase = 6 AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Cierre Fase 6 y Sustentación Aprobada', 6, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="Sustentación aprobada. Proyecto Finalizado."/>
          </sql:update>
        </c:when>
        <c:when test="${param.resultado_sust == 'Rechazado'}">
          <sql:update>
            INSERT INTO sustentaciones (proyecto_id, fecha, hora, lugar_o_enlace, jurados, resultado, numero_acta, observaciones)
            VALUES (?, ?, ?, ?, ?, 'Rechazado', ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${empty param.fecha_sustentacion ? param.acta_fecha : param.fecha_sustentacion}"/>
            <sql:param value="${empty param.hora_sustentacion ? '08:00:00' : param.hora_sustentacion}"/>
            <sql:param value="${empty param.lugar_sustentacion ? 'Auditorio Institucional / Enlace Virtual UTS' : param.lugar_sustentacion}"/>
            <sql:param value="${empty param.jurados_sustentacion ? 'Docentes Jurados de Grado' : param.jurados_sustentacion}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
          <sql:update>
            UPDATE proyectos SET estado = 'Rechazado', responsable = 'comite' WHERE id = ? AND fase = 6 AND estado = 'En curso'
            <sql:param value="${param.proyecto_id}"/>
          </sql:update>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Sustentación Rechazada Fase 6', 6, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="Sustentación rechazada. Proyecto cerrado como Rechazado."/>
          </sql:update>
        </c:when>
        <c:otherwise>
          <%-- Si falta algo, lo solicita y el proyecto sigue en F6·Comité --%>
          <sql:update>
            INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
            VALUES (?, ?, 'Solicitud Comité Fase 6', 6, ?, ?)
            <sql:param value="${param.proyecto_id}"/>
            <sql:param value="${sessionScope.usuario_id}"/>
            <sql:param value="${param.acta_numero}"/>
            <sql:param value="${param.comentarios}"/>
          </sql:update>
        </c:otherwise>
      </c:choose>
      <sql:update>
        INSERT INTO respuestas (proyecto_id, fase, ronda, version_evaluada, usuario_id, rol, estado, acta_numero, acta_fecha, comentario)
        VALUES (?, 6, ?, ?, ?, 'comite', ?, ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${rondaF6.rows[0].sig}"/>
        <sql:param value="${verF6.rows[0].mv}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.resultado_sust == 'Aprobado' ? 'Aprobado' : (param.resultado_sust == 'Rechazado' ? 'Rechazado' : 'Correcciones')}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="${param.acta_fecha}"/>
        <sql:param value="${param.comentarios}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/comite/proyectos.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errFase6}"><c:set var="errorMsg" value="Error en Fase 6. Intente de nuevo."/></c:if>
</c:if>

<%-- Procesamiento: Cancelación de Proyecto por Comité con justificación y acta (estado Cancelado) --%>
<c:if test="${param.accion == 'cancelar_proyecto' and not empty param.proyecto_id}">
  <c:catch var="errCanc">
    <sql:transaction dataSource="${db}">
      <sql:update>
        UPDATE proyectos SET estado = 'Cancelado', responsable = 'comite' WHERE id = ? AND estado = 'En curso'
        <sql:param value="${param.proyecto_id}"/>
      </sql:update>
      <sql:update>
        INSERT INTO historial (proyecto_id, usuario_id, accion, fase, acta_numero, comentario)
        VALUES (?, ?, 'Cancelación de Proyecto por Comité', ?, ?, ?)
        <sql:param value="${param.proyecto_id}"/>
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="${param.fase_actual}"/>
        <sql:param value="${param.acta_numero}"/>
        <sql:param value="Cancelado por Comité. Motivo: ${param.motivo}"/>
      </sql:update>
      <sql:update>
        INSERT INTO auditoria (usuario_id, accion, entidad, detalle)
        VALUES (?, 'Cancelación de Proyecto', 'proyectos', ?)
        <sql:param value="${sessionScope.usuario_id}"/>
        <sql:param value="Comité canceló el proyecto ID ${param.proyecto_id}. Acta: ${param.acta_numero}. Motivo: ${param.motivo}"/>
      </sql:update>
    </sql:transaction>
    <c:redirect url="/comite/proyectos.jsp"><c:param name="ok" value="Respuesta enviada correctamente"/></c:redirect>
  </c:catch>
  <c:if test="${not empty errCanc}"><c:set var="errorMsg" value="Error al cancelar proyecto. Intente de nuevo."/></c:if>
</c:if>

<%-- Docentes para tribunal (misma lista para director y evaluador: todo rol docente activo) --%>
<sql:query dataSource="${db}" var="listaDocentes">
  SELECT u.id, CONCAT(u.nombres, ' ', u.apellidos) AS nombre_completo
  FROM usuarios u
  JOIN usuario_rol ur ON ur.usuario_id = u.id
  JOIN roles r ON r.id = ur.rol_id AND r.nombre = 'docente'
  WHERE u.activo = 1
  ORDER BY u.apellidos, u.nombres
</sql:query>

<%-- Paginación y Búsqueda --%>
<c:set var="limite" value="${empty param.limite ? 5 : param.limite}" />
<c:set var="pagina" value="${empty param.pagina ? 1 : param.pagina}" />
<c:set var="offset" value="${(pagina - 1) * limite}" />
<c:set var="clave" value="${param.clave}" />

<c:choose>
  <c:when test="${not empty clave}">
    <sql:query dataSource="${db}" var="conteoProy">
      SELECT COUNT(*) AS total FROM proyectos p
      WHERE p.codigo LIKE ? OR p.titulo LIKE ?
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, per.codigo AS periodo_codigo,
             CONCAT(u_dir.nombres, ' ', u_dir.apellidos) AS director_nom,
             CONCAT(u_eval.nombres, ' ', u_eval.apellidos) AS evaluador_nom,
             CONCAT(u_cod.nombres, ' ', u_cod.apellidos) AS codirector_nom
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios u_dir ON p.director_id = u_dir.id
      LEFT JOIN usuarios u_eval ON p.evaluador_id = u_eval.id
      LEFT JOIN usuarios u_cod ON p.codirector_id = u_cod.id
      WHERE p.codigo LIKE ? OR p.titulo LIKE ?
      ORDER BY p.id DESC
      LIMIT ${limite} OFFSET ${offset}
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="conteoProy">
      SELECT COUNT(*) AS total FROM proyectos
    </sql:query>
    <sql:query dataSource="${db}" var="proyectos">
      SELECT p.*, per.codigo AS periodo_codigo,
             CONCAT(u_dir.nombres, ' ', u_dir.apellidos) AS director_nom,
             CONCAT(u_eval.nombres, ' ', u_eval.apellidos) AS evaluador_nom,
             CONCAT(u_cod.nombres, ' ', u_cod.apellidos) AS codirector_nom
      FROM proyectos p
      JOIN periodos per ON p.periodo_id = per.id
      LEFT JOIN usuarios u_dir ON p.director_id = u_dir.id
      LEFT JOIN usuarios u_eval ON p.evaluador_id = u_eval.id
      LEFT JOIN usuarios u_cod ON p.codirector_id = u_cod.id
      ORDER BY p.id DESC
      LIMIT ${limite} OFFSET ${offset}
    </sql:query>
  </c:otherwise>
</c:choose>

<c:set var="totalRegistros" value="${conteoProy.rows[0].total}" />
<c:set var="totalPaginas" value="${((totalRegistros + limite - 1) / limite)}" />

<%-- Cargar todos los integrantes de los proyectos en una sola query (sin condicional dentro) --%>
<c:choose>
  <c:when test="${not empty clave}">
    <sql:query dataSource="${db}" var="allIntegrantes">
      SELECT pi.proyecto_id, u.nombres, u.apellidos, u.documento, u.email, u.telefono
      FROM usuarios u
      INNER JOIN proyecto_integrantes pi ON u.id = pi.usuario_id
      INNER JOIN proyectos fp ON fp.id = pi.proyecto_id
      WHERE fp.codigo LIKE ? OR fp.titulo LIKE ?
      <sql:param value="%${clave}%"/><sql:param value="%${clave}%"/>
    </sql:query>
  </c:when>
  <c:otherwise>
    <sql:query dataSource="${db}" var="allIntegrantes">
      SELECT pi.proyecto_id, u.nombres, u.apellidos, u.documento, u.email, u.telefono
      FROM usuarios u
      INNER JOIN proyecto_integrantes pi ON u.id = pi.usuario_id
    </sql:query>
  </c:otherwise>
</c:choose>

<!DOCTYPE html>
<html lang="es">
<head>
  <%@ include file="/WEB-INF/jspf/header.jspf" %>
  <title>Proyectos de GRADO - SIGRADO UTS</title>
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
          <h2 class="page-title">
            Proyectos de <span class="badge-title-box">GRADO</span>
          </h2>
          <div class="d-flex gap-2">
            <span class="btn-icon-sq btn-icon-danger" title="Alertas"><i class="fas fa-exclamation-triangle"></i></span>
            <span class="btn-icon-sq btn-icon-eye" title="Documental"><i class="fas fa-file-alt"></i></span>
            <a href="${pageContext.request.contextPath}/inicio.jsp" class="btn-volver">
              <i class="fas fa-arrow-left"></i> Volver
            </a>
          </div>
        </div>

        <div class="p-3">
          <%-- Controles de búsqueda (Pág. 3 y 4) --%>
          <form method="get" action="proyectos.jsp" class="table-controls">
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

          <%-- Tabla institucional de proyectos de grado --%>
          <div class="table-responsive">
            <table class="table-sigrado">
              <thead>
                <tr>
                  <th style="width: 120px;">ID <i class="fas fa-sort text-muted ms-1"></i></th>
                  <th>Descripción</th>
                  <th style="width: 180px; text-align: center;">Estado</th>
                  <th style="width: 180px; text-align: center;">Acciones</th>
                </tr>
              </thead>
              <tbody>
<c:choose>
                      <c:when test="${proyectos.rowCount > 0}">
                        <c:forEach var="p" items="${proyectos.rows}">
                          <tr>
                        <td class="fw-bold">${p.codigo}</td>
                        <td>${p.titulo}</td>
                        <td style="text-align: center;">
                          <c:choose>
                            <c:when test="${p.estado == 'Finalizado'}">
                              <span class="badge-pill-custom badge-finalizado">Finalizado</span>
                            </c:when>
                            <c:when test="${p.estado == 'Rechazado'}">
                              <span class="badge-pill-custom badge-rechazado">Rechazado</span>
                            </c:when>
                            <c:otherwise>
                              <span class="badge-fase-dual activa-${p.responsable}">
                                <span class="fase-tag">Fase ${p.fase}</span>
                                <span class="actor-tag text-capitalize">${p.responsable}</span>
                              </span>
                            </c:otherwise>
                          </c:choose>
                        </td>
                        <td style="text-align: center;">
                          <%-- 1. OJO: Detalles de la solicitud (Pág. 5) --%>
                          <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalSol${p.id}" title="Ver detalles de solicitud">
                            <i class="fas fa-eye"></i>
                          </button>

                          <%-- 2. MAPA: Seguimiento cronológico de fases (Pág. 4, 6, 7) --%>
                          <a href="${pageContext.request.contextPath}/comite/seguimiento.jsp?id=${p.id}" class="btn-icon-sq btn-icon-map" title="Seguimiento de fases">
                            <i class="fas fa-sitemap"></i>
                          </a>

                          <%-- 3. RESPUESTA: Responder según fase activa --%>
                          <c:choose>
                            <c:when test="${p.fase == 1 and p.responsable == 'comite'}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalFase1_${p.id}" title="Responder Fase 1 (Aprobar/Asignar)">
                                <i class="fas fa-edit"></i>
                              </button>
                            </c:when>
                            <c:when test="${p.fase == 3 and p.responsable == 'comite'}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalFase3_${p.id}" title="Ratificar Fase 3 (Aprobar Propuesta II)">
                                <i class="fas fa-check-double"></i>
                              </button>
                            </c:when>
                            <c:when test="${p.fase == 5 and p.responsable == 'comite'}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalFase5_${p.id}" title="Dictamen Fase 5 (pasa a Fase 6)">
                                <i class="fas fa-award"></i>
                              </button>
                            </c:when>
                            <c:when test="${p.fase == 6 and p.responsable == 'comite' and p.estado == 'En curso'}">
                              <button type="button" class="btn-icon-sq btn-icon-reply" data-bs-toggle="modal" data-bs-target="#modalFase6_${p.id}" title="Cierre Fase 6: registrar sustentación y Finalizar">
                                <i class="fas fa-graduation-cap"></i>
                              </button>
                            </c:when>
                            <c:when test="${p.fase == 6 and p.estado == 'Finalizado'}">
                              <button type="button" class="btn-icon-sq btn-icon-eye" data-bs-toggle="modal" data-bs-target="#modalSust_${p.id}" title="Ver Sustentación y Acta Final">
                                <i class="fas fa-graduation-cap"></i>
                              </button>
                            </c:when>
                            <c:otherwise>
                              <button type="button" class="btn-icon-sq btn-icon-reply" style="opacity: 0.4; cursor: not-allowed;" title="En espera de entrega o revisión de ${p.responsable}" disabled>
                                <i class="fas fa-clock"></i>
                              </button>
                            </c:otherwise>
                          </c:choose>

                          <%-- 4. DOCUMENTOS: Modal de archivos radicados --%>
                          <button type="button" class="btn-icon-sq btn-icon-doc" data-bs-toggle="modal" data-bs-target="#modalDocs${p.id}" title="Ver documentos">
                            <i class="fas fa-folder-open"></i>
                          </button>

                          <%-- 5. HISTORIAL --%>
                          <button type="button" class="btn-icon-sq btn-icon-danger" data-bs-toggle="modal" data-bs-target="#modalHist${p.id}" title="Historial del proyecto">
                            <i class="fas fa-history"></i>
                          </button>

                          <%-- 6. CANCELACIÓN: Si está en curso (Rechazado/Cancelado/Finalizado ya cerrados) --%>
                          <c:if test="${p.estado == 'En curso'}">
                            <button type="button" class="btn-icon-sq btn-icon-ban ms-1" data-bs-toggle="modal" data-bs-target="#modalCancel_${p.id}" title="Cancelar proyecto con acta">
                              <i class="fas fa-ban"></i>
                            </button>
                          </c:if>
                        </td>
                      </tr>

                      <%-- MODAL 1: Detalles de la SOLICITUD (Pág. 5 y 6) --%>
                      <div class="modal fade" id="modalSol${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered modal-lg">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">
                                Detalles de la <span class="badge-title-box">SOLICITUD</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body p-4">
                              <div class="mb-3">
                                <div class="detail-label">Título del proyecto</div>
                                <div class="detail-value fw-bold text-dark">${p.titulo}</div>
                              </div>
                              <div class="row">
                                <div class="col-md-6">
                                  <div class="detail-label">Docentes asignados</div>
                                  <div class="detail-value">
                                    <div><strong>Director:</strong> <c:out value="${empty p.director_nom ? 'No asignado' : p.director_nom}"/></div>
                                    <div><strong>Evaluador:</strong> <c:out value="${empty p.evaluador_nom ? 'No asignado' : p.evaluador_nom}"/></div>
                                    <div><strong>Codirector:</strong> <c:out value="${empty p.codirector_nom ? 'No asignado' : p.codirector_nom}"/></div>
                                  </div>
                                </div>
                                <div class="col-md-6">
                                  <div class="detail-label">Nivel académico</div>
                                  <div class="detail-value">${p.tipo_nivel}</div>
                                  <div class="detail-label">Modalidad</div>
                                  <div class="detail-value">${p.tipo_modalidad}</div>
                                  <div class="detail-label">Periodo académico</div>
                                  <div class="detail-value">${p.periodo_codigo}</div>
                                </div>
                              </div>
<hr class="my-2 text-muted">
                              <div class="detail-label mb-2">Integrantes del proyecto</div>
                              <c:forEach var="integ" items="${allIntegrantes.rows}">
                                <c:if test="${integ.proyecto_id == p.id}">
                                  <div class="p-2 mb-2 bg-light rounded border">
                                    <div class="fw-bold">${integ.nombres} ${integ.apellidos}</div>
                                    <div class="small text-muted">
                                      C.C. ${integ.documento} | ${integ.email} | Cel: ${integ.telefono}
                                    </div>
                                  </div>
                                </c:if>
                              </c:forEach>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm px-4" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%-- MODAL 2: Formulario Respuesta FASE 1 (Pág. 9 y 10) --%>
                      <c:if test="${p.fase == 1 and p.responsable == 'comite'}">
                        <div class="modal fade" id="modalFase1_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="proyectos.jsp">
                                <input type="hidden" name="accion" value="responder_fase1">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Proyecto <span class="badge-title-box">FASE 1</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Estado del proyecto *</label>
                                    <select name="decision_fase1" class="form-select form-select-sm" id="decFase1_${p.id}" required onchange="toggleFase1Campos('${p.id}', this.value)">
                                      <option value="">Seleccione una opción</option>
                                      <option value="Aprobado">Aprobado (asigna tribunal y pasa a Fase 2)</option>
                                      <option value="Correcciones">Correcciones (vuelve al estudiante)</option>
                                      <option value="Rechazado">Rechazado (cierra el proyecto)</option>
                                    </select>
                                  </div>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de acta *</label>
                                      <input type="text" name="acta_numero" class="form-control form-control-sm" required placeholder="Ingrese el número de acta">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del acta *</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm" required>
                                    </div>
                                  </div>

                                  <%-- Campos visibles si es APROBADO (Pág. 10) --%>
                                  <div id="bloqueAprobado_${p.id}" style="display: none;">
                                    <div class="mb-3">
                                      <label class="form-label small fw-bold">Código de modalidad * (125 para Profesional, 65 para Tecnología)</label>
                                      <input type="text" name="codigo_modalidad" id="codMod_${p.id}" class="form-control form-control-sm" 
                                             value="${p.tipo_nivel == 'Profesional' ? '125-2026-001' : '65-2026-001'}" placeholder="ej: 125-2026-001">
                                    </div>
                                    <div class="alert alert-info small mb-3">
                                      <i class="fas fa-info-circle me-1"></i>
                                      Solo se necesitan 2 docentes: director y evaluador (deben ser diferentes). Los mismos docentes pueden ser directores en unos proyectos y evaluadores en otros.
                                    </div>
                                    <div class="mb-3">
                                      <label class="form-label small fw-bold">Asignar el director del proyecto *</label>
                                      <select name="director_id" class="form-select form-select-sm" id="dirSelect_${p.id}">
                                        <option value="">Seleccione un director para el proyecto</option>
                                        <c:forEach var="doc" items="${listaDocentes.rows}">
                                          <option value="${doc.id}">${doc.nombre_completo}</option>
                                        </c:forEach>
                                      </select>
                                    </div>
                                    <div class="mb-3">
                                      <label class="form-label small fw-bold">Asignar el evaluador del proyecto *</label>
                                      <select name="evaluador_id" class="form-select form-select-sm" id="evalSelect_${p.id}">
                                        <option value="">Seleccione un evaluador para el proyecto</option>
                                        <c:forEach var="doc" items="${listaDocentes.rows}">
                                          <option value="${doc.id}">${doc.nombre_completo}</option>
                                        </c:forEach>
                                      </select>
                                    </div>
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios de la respuesta</label>
                                    <textarea name="comentarios" class="form-control form-control-sm" rows="3" placeholder="Describe los detalles de la respuesta para el estudiante"></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Responder</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                      <%-- MODAL 2.5: Formulario Ratificación FASE 3 --%>
                      <c:if test="${p.fase == 3 and p.responsable == 'comite'}">
                        <div class="modal fade" id="modalFase3_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="proyectos.jsp">
                                <input type="hidden" name="accion" value="responder_fase3">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Ratificación Propuesta de Grado - <span class="badge-title-box">FASE 3</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <div class="alert alert-info small mb-3">
                                    <i class="fas fa-info-circle me-1"></i>
                                    El docente evaluador ha evaluado la propuesta (F-DC-124). El Comité debe emitir la resolución y acta correspondiente para autorizar el paso a <strong>Fase 4 (Desarrollo del Informe Final)</strong>.
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Decisión del Comité sobre la Propuesta *</label>
                                    <select name="decision_fase3" class="form-select form-select-sm" required>
                                      <option value="">Seleccione una opción</option>
                                      <option value="Aprobado" selected>Aprobado (Avanza a Fase 4 - Informe Final)</option>
                                      <option value="Correcciones">Correcciones (Vuelve a Fase 2 para correcciones del estudiante)</option>
                                      <option value="Rechazado">Rechazado (Cancelación del proyecto)</option>
                                    </select>
                                  </div>

                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de acta del Comité *</label>
                                      <input type="text" name="acta_numero" class="form-control form-control-sm" required placeholder="ej: ACTA-COM-2026-003">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del acta *</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm" required>
                                    </div>
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios / Observaciones de la Resolución</label>
                                    <textarea name="comentarios" class="form-control form-control-sm" rows="3" placeholder="Detalles de la aprobación o indicaciones para la fase de desarrollo"></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Emitir Resolución y Guardar</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                      <%-- MODAL 3: Formulario Respuesta FASE 5 (Aprobado -> F6, Aplazado/Correcciones -> F4, Rechazado cierra) --%>
                      <c:if test="${p.fase == 5 and p.responsable == 'comite'}">
                        <div class="modal fade" id="modalFase5_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="proyectos.jsp">
                                <input type="hidden" name="accion" value="responder_fase5">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Dictamen Informe II - <span class="badge-title-box">FASE 5</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <div class="alert alert-info small mb-3">
                                    <i class="fas fa-info-circle me-1"></i>
                                    El evaluador ha calificado el informe final y rejilla (F-DC-129). Aprobado pasa a <strong>Fase 6 · Comité</strong>. Aplazado vuelve a <strong>Fase 4 · Estudiante</strong> para versión nueva.
                                  </div>

                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Dictamen del proyecto *</label>
                                    <select name="decision_fase5" class="form-select form-select-sm" required>
                                      <option value="">Seleccione una opción</option>
                                      <option value="Aprobado" selected>Aprobado (pasa a Fase 6 · Comité)</option>
                                      <option value="Aplazado">Aplazado (vuelve a Fase 4 · Estudiante)</option>
                                      <option value="Correcciones">Correcciones (vuelve a Fase 4 · Estudiante)</option>
                                      <option value="Rechazado">Rechazado (cierra el proyecto)</option>
                                    </select>
                                  </div>

                                  <h6 class="fw-bold text-dark mt-2 mb-2 small"><i class="fas fa-file-signature me-1"></i> Documentos y Acta:</h6>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Informe (F-DC-125) firmado (URL https://)</label>
                                      <input type="url" name="informe_fdc125_url" class="form-control form-control-sm" placeholder="https://drive.google.com/file/d/...">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Rejilla (F-DC-129) firmada (URL https://)</label>
                                      <input type="url" name="rejilla_fdc129_url" class="form-control form-control-sm" placeholder="https://drive.google.com/file/d/...">
                                    </div>
                                  </div>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de acta *</label>
                                      <input type="text" name="acta_numero" class="form-control form-control-sm" required placeholder="ej: ACTA-GRAD-2026-045">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del acta *</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm" required>
                                    </div>
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios / Observaciones</label>
                                    <textarea name="comentarios" class="form-control form-control-sm" rows="3" placeholder="Detalles del dictamen"></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Guardar Dictamen</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                      <%-- MODAL 3B: Cierre FASE 6 (registra sustentación y Finaliza; si falta algo sigue en F6·Comité) --%>
                      <c:if test="${p.fase == 6 and p.responsable == 'comite' and p.estado == 'En curso'}">
                        <div class="modal fade" id="modalFase6_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <form method="post" action="proyectos.jsp">
                                <input type="hidden" name="accion" value="responder_fase6">
                                <input type="hidden" name="proyecto_id" value="${p.id}">
                                <div class="modal-header modal-header-sigrado">
                                  <h5 class="modal-title fw-bold">
                                    Cierre y Sustentación - <span class="badge-title-box">FASE 6</span>
                                  </h5>
                                  <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <div class="alert alert-info small mb-3">
                                    <i class="fas fa-info-circle me-1"></i>
                                    Verifique todos los documentos. Registre la sustentación (fecha, lugar o enlace, resultado, acta) y pulse Finalizar. Si falta algo, solicítelo y el proyecto sigue en <strong>F6 · Comité</strong>.
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Resultado de sustentación *</label>
                                    <select name="resultado_sust" class="form-select form-select-sm" required>
                                      <option value="Aprobado" selected>Aprobado (Finaliza el proyecto)</option>
                                      <option value="Aplazado">Solicitar faltantes (sigue en F6 · Comité)</option>
                                      <option value="Rechazado">Rechazado (cierra el proyecto)</option>
                                    </select>
                                  </div>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha de sustentación</label>
                                      <input type="date" name="fecha_sustentacion" class="form-control form-control-sm">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Hora de sustentación</label>
                                      <input type="time" name="hora_sustentacion" class="form-control form-control-sm" value="08:00">
                                    </div>
                                  </div>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Lugar o Enlace Virtual (https://)</label>
                                      <input type="text" name="lugar_sustentacion" class="form-control form-control-sm" placeholder="ej: Auditorio A o https://meet.google.com/...">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Jurados de sustentación</label>
                                      <input type="text" name="jurados_sustentacion" class="form-control form-control-sm" placeholder="ej: Ing. Docente 1, Ing. Docente 2">
                                    </div>
                                  </div>
                                  <div class="row">
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Número de acta final *</label>
                                      <input type="text" name="acta_numero" class="form-control form-control-sm" required placeholder="ej: ACTA-GRAD-2026-045">
                                    </div>
                                    <div class="col-md-6 mb-3">
                                      <label class="form-label small fw-bold">Fecha del acta *</label>
                                      <input type="date" name="acta_fecha" class="form-control form-control-sm" required>
                                    </div>
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Comentarios / Observaciones</label>
                                    <textarea name="comentarios" class="form-control form-control-sm" rows="3" placeholder="Detalles de la sustentación o faltantes solicitados"></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer modal-footer-sigrado">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cancelar</button>
                                  <button type="submit" class="btn btn-uts btn-sm">Guardar y Finalizar</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                      <%-- MODAL 4: Documentos Radicados (Pág. 8 y 21) --%>
                      <div class="modal fade" id="modalDocs${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">
                                Documentos del <span class="badge-title-box">PROYECTO</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body p-4">
                              <sql:query dataSource="${db}" var="docs">
                                SELECT * FROM documentos WHERE proyecto_id = ? ORDER BY fase ASC, version DESC
                                <sql:param value="${p.id}"/>
                              </sql:query>
                              <c:choose>
                                <c:when test="${docs.rowCount > 0}">
                                  <ul class="list-group list-group-flush">
                                    <c:forEach var="d" items="${docs.rows}">
                                      <li class="list-group-item d-flex justify-content-between align-items-center px-0">
                                        <div>
                                          <div class="fw-bold text-dark">${d.tipo} (v${d.version})</div>
                                          <small class="text-muted">${d.nombre_archivo} | Fase ${d.fase}</small>
                                        </div>
                                        <a href="${d.url}" target="_blank" class="btn btn-outline-primary btn-sm">
                                          <i class="fas fa-external-link-alt"></i> Ver
                                        </a>
                                      </li>
                                    </c:forEach>
                                  </ul>
                                </c:when>
                                <c:otherwise>
                                  <div class="text-center text-muted py-3">No hay documentos registrados aún.</div>
                                </c:otherwise>
                              </c:choose>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                            </div>
                          </div>
                        </div>
                      </div>

                      <%-- MODAL 5: Historial y Auditoría --%>
                      <div class="modal fade" id="modalHist${p.id}" tabindex="-1" aria-hidden="true">
                        <div class="modal-dialog modal-dialog-centered modal-lg">
                          <div class="modal-content">
                            <div class="modal-header modal-header-sigrado">
                              <h5 class="modal-title fw-bold">
                                Historial del <span class="badge-title-box">PROYECTO</span>
                              </h5>
                              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                            </div>
                            <div class="modal-body p-4">
                              <sql:query dataSource="${db}" var="hist">
                                SELECT h.*, CONCAT(u.nombres, ' ', u.apellidos) AS autor
                                FROM historial h
                                JOIN usuarios u ON h.usuario_id = u.id
                                WHERE h.proyecto_id = ?
                                ORDER BY h.fecha DESC
                                <sql:param value="${p.id}"/>
                              </sql:query>
                              <c:choose>
                                <c:when test="${hist.rowCount > 0}">
                                  <div class="timeline">
                                    <c:forEach var="h" items="${hist.rows}">
                                      <div class="p-3 mb-2 bg-light rounded border">
                                        <div class="d-flex justify-content-between">
                                          <strong class="text-dark">${h.accion}</strong>
                                          <small class="text-muted">${h.fecha}</small>
                                        </div>
                                        <div class="small text-muted">Por: ${h.autor} <c:if test="${not empty h.acta_numero}">| Acta: ${h.acta_numero}</c:if></div>
                                        <div class="mt-1 small">${h.comentario}</div>
                                      </div>
                                    </c:forEach>
                                  </div>
                                </c:when>
                                <c:otherwise>
                                  <div class="text-center text-muted py-3">Sin movimientos registrados.</div>
                                </c:otherwise>
                              </c:choose>
                            </div>
                            <div class="modal-footer modal-footer-sigrado">
                              <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                      <%-- MODAL 6: Sustentación y Acta Final --%>
                      <c:if test="${p.fase == 6 and p.estado == 'Finalizado'}">
                        <div class="modal fade" id="modalSust_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered modal-lg">
                            <div class="modal-content">
                              <div class="modal-header modal-header-sigrado">
                                <h5 class="modal-title fw-bold">
                                  Acta de Sustentación - <span class="badge-title-box">FINALIZADO</span>
                                </h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                              </div>
                              <div class="modal-body p-4">
                                <sql:query dataSource="${db}" var="sustData">
                                  SELECT * FROM sustentaciones WHERE proyecto_id = ? ORDER BY id DESC LIMIT 1
                                  <sql:param value="${p.id}"/>
                                </sql:query>
                                <c:choose>
                                  <c:when test="${sustData.rowCount > 0}">
                                    <c:set var="sd" value="${sustData.rows[0]}"/>
                                    <div class="p-3 mb-3 bg-light rounded-3 border">
                                      <div class="row g-3">
                                        <div class="col-md-6">
                                          <div class="detail-label">Fecha y Hora de Sustentación</div>
                                          <div class="detail-value fw-bold text-dark"><fmt:formatDate value="${sd.fecha}" pattern="dd/MM/yyyy"/> - ${sd.hora}</div>
                                        </div>
                                        <div class="col-md-6">
                                          <div class="detail-label">Resultado Oficial</div>
                                          <div class="detail-value"><span class="badge bg-success">${sd.resultado}</span></div>
                                        </div>
                                        <div class="col-md-6">
                                          <div class="detail-label">Número de Acta Final</div>
                                          <div class="detail-value fw-bold text-dark">${sd.numero_acta}</div>
                                        </div>
                                        <div class="col-md-6">
                                          <div class="detail-label">Lugar o Enlace</div>
                                          <div class="detail-value">${sd.lugar_o_enlace}</div>
                                        </div>
                                        <div class="col-12">
                                          <div class="detail-label">Jurados Evaluadores</div>
                                          <div class="detail-value">${sd.jurados}</div>
                                        </div>
                                        <c:if test="${not empty sd.observaciones}">
                                          <div class="col-12">
                                            <div class="detail-label">Observaciones y Menciones</div>
                                            <div class="detail-value p-2 bg-white rounded border">${sd.observaciones}</div>
                                          </div>
                                        </c:if>
                                      </div>
                                    </div>
                                  </c:when>
                                  <c:otherwise>
                                    <div class="alert alert-info small mb-0">
                                      Este proyecto ha culminado exitosamente según los registros del Comité.
                                    </div>
                                  </c:otherwise>
                                </c:choose>
                              </div>
                              <div class="modal-footer modal-footer-sigrado">
                                <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Cerrar</button>
                              </div>
                            </div>
                          </div>
                        </div>
                      </c:if>

                      <%-- MODAL 7: Cancelación de Proyecto por Comité --%>
                      <c:if test="${p.estado == 'En curso'}">
                        <div class="modal fade" id="modalCancel_${p.id}" tabindex="-1" aria-hidden="true">
                          <div class="modal-dialog modal-dialog-centered">
                            <div class="modal-content">
                              <form method="post" action="proyectos.jsp">
                                <input type="hidden" name="accion" value="cancelar_proyecto"/>
                                <input type="hidden" name="proyecto_id" value="${p.id}"/>
                                <input type="hidden" name="fase_actual" value="${p.fase}"/>
                                <div class="modal-header bg-danger text-white">
                                  <h5 class="modal-title fw-bold">
                                    <i class="fas fa-ban me-1"></i> Cancelar Proyecto de Grado
                                  </h5>
                                  <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
                                </div>
                                <div class="modal-body p-4">
                                  <div class="alert alert-warning small mb-3">
                                    <i class="fas fa-exclamation-triangle me-1"></i>
                                    Esta acción cambiará el estado del proyecto <strong>${p.codigo}</strong> a <strong>Cancelado</strong> y registrará formalmente la cancelación en la bitácora y auditoría institucional.
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Número de acta del Comité *</label>
                                    <input type="text" name="acta_numero" class="form-control form-control-sm" required placeholder="ej: ACTA-CANC-2026-001">
                                  </div>
                                  <div class="mb-3">
                                    <label class="form-label small fw-bold">Motivo o justificación de la cancelación *</label>
                                    <textarea name="motivo" class="form-control form-control-sm" rows="3" required placeholder="Explica detalladamente la causa formal de la cancelación (incumplimiento, solicitud voluntaria, etc.)"></textarea>
                                  </div>
                                </div>
                                <div class="modal-footer">
                                  <button type="button" class="btn btn-secondary btn-sm" data-bs-dismiss="modal">Volver</button>
                                  <button type="submit" class="btn btn-danger btn-sm">Confirmar Cancelación</button>
                                </div>
                              </form>
                            </div>
                          </div>
                        </div>
                      </c:if>

                    </c:forEach>
                  </c:when>
                  <c:otherwise>
                    <tr>
                      <td colspan="4" class="text-center py-4 text-muted">
                        <i class="fas fa-folder-open fa-2x mb-2 d-block"></i>
                        No se encontraron proyectos registrados
                      </td>
                    </tr>
                  </c:otherwise>
                </c:choose>
              </tbody>
            </table>
          </div>

          <%-- Paginador --%>
          <div class="d-flex justify-content-between align-items-center mt-3 flex-wrap">
            <div class="small text-muted">
              Mostrando registros de ${offset + 1} a ${offset + proyectos.rowCount} de un total de ${totalRegistros}
            </div>
            <div class="d-flex gap-1">
              <c:if test="${pagina > 1}">
                <a href="proyectos.jsp?pagina=${pagina - 1}&limite=${limite}&clave=${clave}" class="btn btn-outline-secondary btn-sm">Anterior</a>
              </c:if>
              <span class="btn btn-uts btn-sm">${pagina}</span>
              <c:if test="${pagina < totalPaginas}">
                <a href="proyectos.jsp?pagina=${pagina + 1}&limite=${limite}&clave=${clave}" class="btn btn-outline-secondary btn-sm">Siguiente</a>
              </c:if>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <script>
    function toggleFase1Campos(id, val) {
      const bloque = document.getElementById('bloqueAprobado_' + id);
      const dirSelect = document.getElementById('dirSelect_' + id);
      const evalSelect = document.getElementById('evalSelect_' + id);
      const codMod = document.getElementById('codMod_' + id);

      if (val === 'Aprobado') {
        bloque.style.display = 'block';
        dirSelect.required = true;
        evalSelect.required = true;
        codMod.required = true;
      } else {
        bloque.style.display = 'none';
        dirSelect.required = false;
        evalSelect.required = false;
        codMod.required = false;
      }
    }
  </script>

  <%@ include file="/WEB-INF/jspf/footer.jspf" %>
</body>
</html>

