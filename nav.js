/* Scroll-spy for the rail nav. Marks the topmost visible section
   active. Anchors still work with JavaScript off — this only adds the
   gold dot. */
(function () {
  var links = Array.prototype.slice.call(document.querySelectorAll('.nav a'));
  var map = {};
  var targets = [];

  links.forEach(function (a) {
    var href = a.getAttribute('href') || '';
    if (href.charAt(0) !== '#') { return; }
    var el = document.querySelector(href);
    if (el) { map[el.id] = a; targets.push(el); }
  });

  if (!targets.length) { return; }

  function setActive(id) {
    links.forEach(function (a) { a.classList.toggle('is-active', a === map[id]); });
  }

  setActive(targets[0].id);

  if (!('IntersectionObserver' in window)) { return; }

  var seen = {};
  var io = new IntersectionObserver(function (entries) {
    entries.forEach(function (e) { seen[e.target.id] = e.isIntersecting; });
    for (var i = 0; i < targets.length; i++) {
      if (seen[targets[i].id]) { setActive(targets[i].id); return; }
    }
  }, { rootMargin: '-10% 0px -70% 0px', threshold: 0 });

  targets.forEach(function (t) { io.observe(t); });
})();
