/* Sidebar scroll-spy, plus the mobile top bar.
   ------------------------------------------------------------------
   The top bar is built here rather than written into both pages: it
   clones the rail's mark, name and links, so there is one source of
   truth for the navigation and nothing to keep in sync. With
   JavaScript off, the rail at the top of the page is still a complete,
   usable nav — it just scrolls away, which is where this came from.

   It is position: fixed, not sticky. A sticky element that changes
   height shifts everything below it; a fixed one is out of flow, so
   the bar can slide in without the page jumping under the reader. */
(function () {
  'use strict';

  var rail   = document.querySelector('.rail');
  var links  = Array.prototype.slice.call(document.querySelectorAll('.nav a'));
  if (!rail || !links.length) { return; }

  /* ---------------------------------------------------------- spy */

  var map = {}, targets = [];

  links.forEach(function (a) {
    var href = a.getAttribute('href') || '';
    if (href.charAt(0) !== '#') { return; }
    var el = document.querySelector(href);
    if (el) { map[el.id] = a; targets.push(el); }
  });

  /* ------------------------------------------------------ top bar */

  var bar = null, toggle = null, barMap = {};

  function buildBar() {
    var mark = rail.querySelector('.monogram');
    var name = rail.querySelector('.rail-name');
    if (!mark || !name) { return; }

    bar = document.createElement('div');
    bar.className = 'topbar';

    var row = document.createElement('div');
    row.className = 'topbar-row';

    // The mark goes home on both pages: the case study's is already a
    // link, the home page's is not.
    var markLink = document.createElement('a');
    markLink.className = 'topbar-mark';
    markLink.href = mark.tagName === 'A' ? mark.getAttribute('href') : '#about';
    markLink.setAttribute('aria-label', 'Top of page');
    markLink.innerHTML = mark.innerHTML;

    var title = document.createElement('span');
    title.className = 'topbar-name';
    title.textContent = name.textContent;

    toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'topbar-toggle';
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-controls', 'topbar-menu');
    toggle.setAttribute('aria-label', 'Open navigation');
    toggle.innerHTML = '<span></span><span></span><span></span>';

    row.appendChild(markLink);
    row.appendChild(title);
    row.appendChild(toggle);

    var menu = document.createElement('nav');
    menu.className = 'topbar-menu';
    menu.id = 'topbar-menu';
    menu.setAttribute('aria-label', 'Sections');

    links.forEach(function (a) {
      var copy = document.createElement('a');
      copy.href = a.getAttribute('href');
      copy.textContent = a.textContent;
      copy.addEventListener('click', function () { closeMenu(); });
      menu.appendChild(copy);
      var href = a.getAttribute('href') || '';
      if (href.charAt(0) === '#') { barMap[href.slice(1)] = copy; }
    });

    bar.appendChild(row);
    bar.appendChild(menu);
    document.body.appendChild(bar);

    toggle.addEventListener('click', function () {
      bar.classList.contains('is-open') ? closeMenu() : openMenu();
    });
  }

  function openMenu() {
    bar.classList.add('is-open');
    toggle.setAttribute('aria-expanded', 'true');
    toggle.setAttribute('aria-label', 'Close navigation');
  }

  function closeMenu() {
    if (!bar) { return; }
    bar.classList.remove('is-open');
    toggle.setAttribute('aria-expanded', 'false');
    toggle.setAttribute('aria-label', 'Open navigation');
  }

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { closeMenu(); }
  });

  /* -------------------------------------------------------- state */

  function setActive(id) {
    links.forEach(function (a) { a.classList.toggle('is-active', a === map[id]); });
    if (bar) {
      Object.keys(barMap).forEach(function (key) {
        barMap[key].classList.toggle('is-active', key === id);
      });
    }
  }

  var shown = false;

  function onScroll(force) {
    if (!bar) { return; }
    // Reveal once the rail has scrolled out of reach. The 12px of slack
    // stops the bar flickering at the boundary.
    var past = window.pageYOffset > rail.offsetHeight - 12;
    if (!force && past === shown) { return; }
    shown = past;
    bar.classList.toggle('is-visible', past);
    if (!past) { closeMenu(); }
  }

  buildBar();

  if (targets.length) {
    setActive(targets[0].id);

    if ('IntersectionObserver' in window) {
      var seen = {};
      var io = new IntersectionObserver(function (entries) {
        entries.forEach(function (e) { seen[e.target.id] = e.isIntersecting; });
        for (var i = 0; i < targets.length; i++) {
          if (seen[targets[i].id]) { setActive(targets[i].id); return; }
        }
      }, { rootMargin: '-10% 0px -70% 0px', threshold: 0 });
      targets.forEach(function (t) { io.observe(t); });
    }
  }

  window.addEventListener('scroll', onScroll, { passive: true });
  // A resize changes the rail's height, so the threshold moves. Force
  // the recompute rather than trusting the cached state — inverting the
  // cached flag to trigger it silently does the wrong thing whenever
  // the new state happens to match the inverted one.
  window.addEventListener('resize', function () {
    closeMenu();
    onScroll(true);
  });
  onScroll(true);
})();
