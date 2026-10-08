// main.js - Funciones comunes UI para SIGRADO
document.addEventListener('DOMContentLoaded', function() {
  const sidebar = document.getElementById('sidebar');
  const backdrop = document.getElementById('sidebarBackdrop');
  const toggleBtn = document.getElementById('sidebarToggle');
  const floatToggle = document.getElementById('sidebarFloatToggle');

  const isOpen = () => !!(sidebar && (sidebar.classList.contains('show') || sidebar.classList.contains('open')));

  // Si la página ya tiene su propio botón de menú (topbar.jspf o los
  // .hamburger antiguos) se usa ese y no se muestra el flotante global.
  if (sidebar) {
    const inlineToggle = toggleBtn || document.querySelector('.hamburger');
    document.body.classList.toggle('sidebar-float', !inlineToggle);
    if (floatToggle) floatToggle.hidden = !!inlineToggle;
  }

  function setSidebarState(open) {
    if (!sidebar) return;
    sidebar.classList.toggle('show', open);
    sidebar.classList.toggle('open', open);
    sidebar.setAttribute('aria-hidden', open ? 'false' : 'true');
    if (backdrop) backdrop.classList.toggle('show', open);
    [toggleBtn, floatToggle].forEach(function(btn) {
      if (btn) btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
  }

  [toggleBtn, floatToggle].forEach(function(btn) {
    if (!btn) return;
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      e.stopPropagation();
      setSidebarState(!isOpen());
    });
  });

  if (backdrop) {
    backdrop.addEventListener('click', function() {
      setSidebarState(false);
    });
  }

  // Cerrar el cajón al navegar a otra página (móvil)
  if (sidebar) {
    sidebar.querySelectorAll('.sidebar-link').forEach(function(link) {
      link.addEventListener('click', function() {
        if (window.innerWidth < 992) setSidebarState(false);
      });
    });
  }

  // Al volver a desktop el sidebar queda siempre visible
  window.addEventListener('resize', function() {
    if (window.innerWidth >= 992) setSidebarState(false);
  });

  // Estado inicial: cerrado en móvil, visible en desktop
  if (window.innerWidth < 992) setSidebarState(false);

  // Cerrar el cajón al hacer click fuera en móvil
  document.addEventListener('click', function(e) {
    if (window.innerWidth < 992 && isOpen() && sidebar && !sidebar.contains(e.target)) {
      if (!floatToggle || !floatToggle.contains(e.target)) setSidebarState(false);
    }
  });

  // Filtrado de tablas en vivo
  const tableSearchInputs = document.querySelectorAll('.table-search-input');
  tableSearchInputs.forEach(input => {
    input.addEventListener('input', function() {
      const targetTableId = this.getAttribute('data-target-table');
      const table = document.getElementById(targetTableId);
      if (!table) return;
      const term = this.value.toLowerCase().trim();
      const rows = table.querySelectorAll('tbody tr');
      rows.forEach(row => {
        const text = row.innerText.toLowerCase();
        row.style.display = text.includes(term) ? '' : 'none';
      });
    });
  });

  // Inicializar tooltips de Bootstrap
  try {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.forEach(function (tooltipTriggerEl) {
      new bootstrap.Tooltip(tooltipTriggerEl);
    });
  } catch (e) {
    // Fallback nativo con atributo title
  }
});

// Botón hamburguesa embebido en los topbars antiguos
function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;
  const backdrop = document.getElementById('sidebarBackdrop');
  const open = !(sidebar.classList.contains('show') || sidebar.classList.contains('open'));
  sidebar.classList.toggle('show', open);
  sidebar.classList.toggle('open', open);
  if (backdrop) backdrop.classList.toggle('show', open);
}

// Vuelve a mostrar el sidebar al imprimir (evita páginas recortadas)
window.addEventListener('beforeprint', function() {
  const sidebar = document.getElementById('sidebar');
  const backdrop = document.getElementById('sidebarBackdrop');
  if (sidebar) { sidebar.classList.remove('show', 'open'); }
  if (backdrop) backdrop.classList.remove('show');
});

function showToast(titulo, mensaje, tipo) {
  const container = document.getElementById('toast-container') || createToastContainer();
  const toastEl = document.createElement('div');
  toastEl.className = `toast align-items-center text-white bg-${tipo} border-0 shadow`;
  toastEl.setAttribute('role', 'alert');
  toastEl.innerHTML = `
    <div class="d-flex">
      <div class="toast-body">
        <strong>${titulo}:</strong> ${mensaje}
      </div>
      <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
    </div>`;
  container.appendChild(toastEl);
  const toast = new bootstrap.Toast(toastEl, { delay: 4000 });
  toast.show();
  toastEl.addEventListener('hidden.bs.toast', () => toastEl.remove());
}

function createToastContainer() {
  const div = document.createElement('div');
  div.id = 'toast-container';
  div.className = 'toast-container position-fixed top-0 end-0 p-3';
  div.style.zIndex = '1090';
  document.body.appendChild(div);
  return div;
}