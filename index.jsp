<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c"   uri="http://java.sun.com/jsp/jstl/core" %>
<%@ taglib prefix="sql" uri="http://java.sun.com/jsp/jstl/sql" %>
<%@ taglib prefix="fn"  uri="http://java.sun.com/jsp/jstl/functions" %>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt" %>
<%@ include file="/WEB-INF/jspf/conexion.jspf" %>

<fmt:requestEncoding value="UTF-8"/>

<sql:query dataSource="${db}" var="periodoActivo">
  SELECT * FROM periodos WHERE activo=1 LIMIT 1
</sql:query>

<sql:query dataSource="${db}" var="formatos">
  SELECT * FROM formatos WHERE activo=1 ORDER BY codigo
</sql:query>

<sql:query dataSource="${db}" var="fasesInfo">
  SELECT * FROM (
    SELECT 1 AS num, 'Pago e Inscripción' AS titulo, 'El estudiante radica su idea (propia o del banco) y adjunta el comprobante de pago de derechos de grado. El Comité revisa y aprueba, asignando tribunal (director y evaluador) y código de modalidad (65 tecnológico, 125 profesional + año + consecutivo).' AS descripcion
    UNION SELECT 2, 'Propuesta I (F-DC-124)', 'El estudiante entrega la propuesta de grado (formato F-DC-124) y reporte Turnitin. El director revisa, verifica originalidad y emite dictamen (Aprobado / Correcciones / Rechazado).'
    UNION SELECT 3, 'Propuesta II (Evaluación)', 'El director envía la propuesta al evaluador para revisión a ciegas. El evaluador emite dictamen. El Comité ratifica con acta y autoriza el paso a desarrollo del informe final.'
    UNION SELECT 4, 'Informe I (F-DC-125)', 'El estudiante entrega el informe final de grado (formato F-DC-125) y reporte Turnitin. El director revisa y emite dictamen.'
    UNION SELECT 5, 'Informe II (F-DC-129)', 'El director envía el informe al evaluador. El evaluador califica con rejilla F-DC-129 y emite dictamen. El Comité emite dictamen con acta y pasa a Fase 6.'
    UNION SELECT 6, 'Sustentación y Cierre', 'Verificación de documentos, sustentación pública registrada por el Comité y cierre del proyecto con estado Finalizado.'
  ) AS f ORDER BY num
</sql:query>

<%-- Página de aterrizaje pública: se muestra siempre, con o sin sesión. --%>
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="SIGRADO - Plataforma institucional UTS para radicación, seguimiento y evaluación de trabajos de grado en 6 fases.">
  <title>SIGRADO - Sistema de Gestión de Trabajos de Grado UTS</title>
  <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/css/bootstrap.min.css" rel="stylesheet">
  <link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css" rel="stylesheet">
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;400;500;600;700&display=swap" rel="stylesheet">
  <link href="${pageContext.request.contextPath}/css/estilos.css?v=emerald1" rel="stylesheet">
  <noscript><style>.reveal-on-scroll{opacity:1 !important;transform:none !important;}</style></noscript>
</head>
<body class="landing-body">
  <a class="skip-link" href="#proceso">Saltar al contenido</a>
  <nav class="navbar navbar-expand-lg navbar-landing fixed-top" aria-label="Navegación principal">
    <div class="container">
      <a class="navbar-brand d-flex align-items-center gap-2" href="index.jsp">
        <span class="uts-badge">SIGRADO</span>
        <span class="brand-text">Sistema de Gestión de Trabajos de Grado</span>
      </a>
      <button class="navbar-toggler navbar-toggler-landing" type="button" data-bs-toggle="collapse" data-bs-target="#landingNav"
              aria-controls="landingNav" aria-expanded="false" aria-label="Abrir menú de navegación">
        <i class="fas fa-bars" aria-hidden="true"></i>
      </button>
      <div class="collapse navbar-collapse justify-content-end" id="landingNav">
        <ul class="navbar-nav">
          <li class="nav-item"><a class="nav-link" href="#proceso">Proceso</a></li>
          <li class="nav-item"><a class="nav-link" href="#fases">Fases</a></li>
          <li class="nav-item"><a class="nav-link" href="#calendario">Calendario</a></li>
          <li class="nav-item"><a class="nav-link" href="#formatos">Formatos</a></li>
        </ul>
        <a href="login.jsp" class="btn btn-uts ms-lg-3 mt-2 mt-lg-0">Ingresar</a>
      </div>
    </div>
  </nav>

  <c:if test="${not empty param.ok}">
    <div class="container" style="padding-top: 5.5rem;">
      <div class="alert alert-success alert-dismissible fade show" role="alert">
        <i class="fas fa-check-circle me-2" aria-hidden="true"></i><c:out value="${param.ok}"/>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
    </div>
  </c:if>
  <c:if test="${not empty param.error}">
    <div class="container" style="padding-top: 5.5rem;">
      <div class="alert alert-danger alert-dismissible fade show" role="alert">
        <i class="fas fa-exclamation-circle me-2" aria-hidden="true"></i><c:out value="${param.error}"/>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
    </div>
  </c:if>

  <section class="hero-landing" aria-labelledby="hero-title">
    <div class="container">
      <div class="row justify-content-center">
        <div class="col-lg-8 text-center">
          <span class="badge badge-program">UNIVERSIDAD TECNOLÓGICA DE SANTANDER</span>
          <h1 id="hero-title" class="display-4 fw-bold mt-3 mb-3">
            Gestión Integral de <span class="badge-title-box">Trabajos de Grado</span>
          </h1>
          <p class="lead hero-lead mx-auto">
            Plataforma institucional para la radicación, seguimiento y evaluación de proyectos de grado.
            Automatiza las 6 fases del proceso: desde la inscripción en el banco de ideas hasta la sustentación final.
          </p>
          <div class="btn-group-landing mt-4">
            <c:choose>
              <c:when test="${not empty sessionScope.usuario_id}">
                <a href="inicio.jsp" class="btn btn-uts-lg">
                  <i class="fas fa-home me-2" aria-hidden="true"></i> Ir a mi panel
                </a>
              </c:when>
              <c:otherwise>
                <a href="login.jsp" class="btn btn-uts-lg">
                  <i class="fas fa-sign-in-alt me-2" aria-hidden="true"></i> Ingresar al Sistema
                </a>
              </c:otherwise>
            </c:choose>
            <a href="#fases" class="btn btn-outline-light-lg">
              <i class="fas fa-route me-2" aria-hidden="true"></i> Ver Fases del Proceso
            </a>
          </div>
          <div class="alert alert-info mt-4 mx-auto text-start demo-accounts-landing" role="alert">
            <i class="fas fa-info-circle me-2" aria-hidden="true"></i>
            <strong>Cuentas de prueba (clave: 123456):</strong>
            <ul class="mb-0 mt-2">
              <li>Comité: <code>comite@uts.edu.co</code></li>
              <li>Administrador: <code>admin@uts.edu.co</code></li>
              <li>Docente: <code>director@uts.edu.co</code></li>
              <li>Estudiante: <code>est1@uts.edu.co</code></li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  </section>

  <section id="proceso" class="py-5 bg-white">
    <div class="container">
      <div class="row justify-content-center mb-5">
        <div class="col-lg-8 text-center">
          <span class="section-title badge-title-box">PROCESO</span>
          <h2 class="fw-bold mt-2">¿Cómo funciona SIGRADO?</h2>
          <p class="section-subtitle">
            Un flujo estructurado de 6 fases que garantiza trazabilidad, calidad y cumplimiento normativo
            en la gestión de trabajos de grado de la Ingeniería de Sistemas UTS.
          </p>
        </div>
      </div>
      <div class="row g-4">
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-green mb-3"><i class="fas fa-lightbulb"></i></div>
            <h5>1. Banco de Ideas</h5>
            <p>Docentes publican propuestas institucionales. Estudiantes eligen una o proponen su propia idea.</p>
          </div>
        </div>
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-blue mb-3"><i class="fas fa-file-contract"></i></div>
            <h5>2. Inscripción y Pago</h5>
            <p>El estudiante adjunta comprobante de pago. Comité aprueba, asigna tribunal y código de modalidad.</p>
          </div>
        </div>
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-navy mb-3"><i class="fas fa-route"></i></div>
            <h5>3. Seguimiento 6 Fases</h5>
            <p>Propuesta I, Propuesta II, Informe I, Informe II, Sustentación. Cada fase con responsable, actas y versiones.</p>
          </div>
        </div>
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-purple mb-3"><i class="fas fa-users-cog"></i></div>
            <h5>4. Roles Diferenciados</h5>
            <p>Administrador, Comité, Docente (Director/Evaluador), Estudiante. Permisos validados en backend.</p>
          </div>
        </div>
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-orange mb-3"><i class="fas fa-file-signature"></i></div>
            <h5>5. Documentos Versionados</h5>
            <p>Entregas por URL (Drive/OneDrive). Versionado automático. Historial completo de correcciones.</p>
          </div>
        </div>
        <div class="col-md-4">
          <div class="landing-card h-100 p-4">
            <div class="icon-wrapper icon-teal mb-3"><i class="fas fa-calendar-check"></i></div>
            <h5>6. Calendario Institucional</h5>
            <p>Fechas de periodos, apertura/cierre de banco, plazos de entrega. Un solo periodo activo a la vez.</p>
          </div>
        </div>
      </div>
    </div>
  </section>

  <section id="fases" class="fases-section py-5">
    <div class="container">
      <div class="row justify-content-center mb-5">
        <div class="col-lg-8 text-center">
          <span class="section-title badge-title-box">FASES</span>
          <h2 class="fw-bold mt-2">Las 6 Fases Institucionales</h2>
          <p class="section-subtitle">
            Cada fase tiene responsable definido, documentos obligatorios, actas y transición de estado controlada.
          </p>
        </div>
      </div>
      <div class="row g-4">
        <c:forEach var="f" items="${fasesInfo.rows}">
          <div class="col-lg-4 col-md-6">
            <div class="fase-card-item reveal-on-scroll delay-${f.num}">
              <div class="fase-badge-num ${f.num == 6 ? 'fase-6' : ''}">${f.num}</div>
              <h6>${f.titulo}</h6>
              <p>${f.descripcion}</p>
            </div>
          </div>
        </c:forEach>
      </div>
    </div>
  </section>

  <section id="calendario" class="py-5 bg-white">
    <div class="container">
      <c:if test="${periodoActivo.rowCount > 0}">
        <c:set var="p" value="${periodoActivo.rows[0]}"/>
        <div class="row justify-content-center mb-5">
          <div class="col-lg-8 text-center">
            <span class="section-title badge-title-box">CALENDARIO</span>
            <h2 class="fw-bold mt-2">Periodo Académico Vigente: <span style="color:#047857;">${p.codigo}</span></h2>
            <p class="section-subtitle">Fechas oficiales para la gestión de propuestas y proyectos de grado.</p>
          </div>
        </div>
        <div class="row justify-content-center">
          <div class="col-lg-10">
            <div class="calendario-card">
              <div class="card-header-custom">
                <div>
                  <span class="badge-periodo">${p.codigo}</span>
                  <h5 class="periodo-title mt-2">Periodo Activo</h5>
                  <span class="badge-activo mt-2 d-inline-block"><i class="fas fa-circle text-success me-1" style="font-size:0.5rem;"></i> Vigente</span>
                </div>
              </div>
              <div class="card-body">
                <div class="row g-3">
                  <div class="col-md-3">
                    <div class="date-item">
                      <div class="date-label">Inicio Propuestas Banco</div>
                      <div class="date-value"><fmt:formatDate value="${p.inicio_propuestas_banco}" pattern="dd/MM/yyyy"/></div>
                    </div>
                  </div>
                  <div class="col-md-3">
                    <div class="date-item">
                      <div class="date-label">Fin Propuestas Banco</div>
                      <div class="date-value"><fmt:formatDate value="${p.fin_propuestas_banco}" pattern="dd/MM/yyyy"/></div>
                    </div>
                  </div>
                  <div class="col-md-3">
                    <div class="date-item">
                      <div class="date-label">Inicio Nuevos Proyectos</div>
                      <div class="date-value"><fmt:formatDate value="${p.inicio_nuevos_proyectos}" pattern="dd/MM/yyyy"/></div>
                    </div>
                  </div>
                  <div class="col-md-3">
                    <div class="date-item">
                      <div class="date-label">Fin Aprobación Propuesta</div>
                      <div class="date-value"><fmt:formatDate value="${p.fin_aprobacion_propuesta}" pattern="dd/MM/yyyy"/></div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </c:if>
      <c:if test="${periodoActivo.rowCount == 0}">
        <div class="alert alert-warning text-center">
          <i class="fas fa-exclamation-triangle me-2"></i> No hay periodo académico activo configurado.
        </div>
      </c:if>
    </div>
  </section>

  <section id="formatos" class="py-5 bg-light">
    <div class="container">
      <div class="row justify-content-center mb-5">
        <div class="col-lg-8 text-center">
          <span class="section-title badge-title-box">FORMATOS</span>
          <h2 class="fw-bold mt-2">Formatos de Grado Institucionales</h2>
          <p class="section-subtitle">Plantillas oficiales UTS para cada entrega del proceso de grado.</p>
        </div>
      </div>
      <div class="row g-4">
        <c:forEach var="fmt" items="${formatos.rows}">
          <div class="col-lg-4 col-md-6">
            <div class="format-card">
              <span class="format-code">${fmt.codigo}</span>
              <h6>${fmt.nombre}</h6>
              <a href="${fmt.url}" target="_blank" rel="noopener noreferrer" class="btn-format">
                <i class="fas fa-download me-1" aria-hidden="true"></i> Descargar Plantilla
              </a>
            </div>
          </div>
        </c:forEach>
        <c:if test="${formatos.rowCount == 0}">
          <div class="col-12">
            <div class="alert alert-warning text-center mb-0">
              <i class="fas fa-exclamation-triangle me-2" aria-hidden="true"></i> Aún no hay formatos publicados. Ingrese al sistema para gestionarlos.
            </div>
          </div>
        </c:if>
      </div>
    </div>
  </section>

  <footer class="footer-landing">
    <div class="container text-center">
      <div class="footer-brand">SIGRADO - UTS</div>
      <div class="footer-copy">Sistema de Gestión y Seguimiento de Trabajos de Grado - Ingeniería de Sistemas</div>
      <div class="footer-copy mt-1">&copy; 2026 Universidad Tecnológica de Santander. Todos los derechos reservados.</div>
    </div>
  </footer>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.2/dist/js/bootstrap.bundle.min.js"></script>
  <script>
    (function () {
      var els = document.querySelectorAll('.reveal-on-scroll');
      if (!('IntersectionObserver' in window) || !els.length) {
        els.forEach(function (el) { el.classList.add('visible'); });
        return;
      }
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible');
            observer.unobserve(entry.target);
          }
        });
      }, { threshold: 0.1 });
      els.forEach(function (el) { observer.observe(el); });
    })();
  </script>
</body>
</html>