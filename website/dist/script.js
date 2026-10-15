document.documentElement.classList.remove("no-js");
document.documentElement.classList.add("js");

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const supportsScrollTimeline =
  CSS.supports("animation-timeline: view()") || CSS.supports("animation-timeline", "view()");

if (!supportsScrollTimeline) {
  document.documentElement.classList.add("no-scroll-timeline");
}

const header = document.querySelector("[data-header]");
const hero = document.querySelector("[data-hero]");
const heroStage = document.querySelector(".hero-stage");
const menuButton = document.querySelector(".menu-button");
const siteNav = document.querySelector(".site-nav");
const toast = document.querySelector("[data-toast]");

if (header && hero && "IntersectionObserver" in window) {
  const headerObserver = new IntersectionObserver(
    ([entry]) => header.classList.toggle("is-scrolled", entry.intersectionRatio < 0.94),
    { threshold: [0.94] },
  );
  headerObserver.observe(hero);
} else if (header) {
  header.classList.add("is-scrolled");
}

const revealItems = [...document.querySelectorAll("[data-reveal]")];

if (reducedMotion || !("IntersectionObserver" in window)) {
  revealItems.forEach((item) => item.classList.add("is-visible"));
} else {
  const revealObserver = new IntersectionObserver(
    (entries, observer) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      });
    },
    { rootMargin: "0px 0px -14%", threshold: 0.14 },
  );
  revealItems.forEach((item) => revealObserver.observe(item));
}

if (hero && heroStage && !reducedMotion) {
  let frame = 0;
  let lightX = 72;
  let lightY = 32;
  let tiltX = 0;
  let tiltY = 0;

  const paintStage = () => {
    hero.style.setProperty("--light-x", `${lightX}%`);
    hero.style.setProperty("--light-y", `${lightY}%`);
    heroStage.style.setProperty("--tilt-x", `${tiltX}deg`);
    heroStage.style.setProperty("--tilt-y", `${tiltY}deg`);
    frame = 0;
  };

  const queuePaint = () => {
    if (!frame) frame = requestAnimationFrame(paintStage);
  };

  const clamp = (value) => Math.min(1, Math.max(0, value));

  hero.addEventListener("pointermove", (event) => {
    const heroBounds = hero.getBoundingClientRect();
    const stageBounds = heroStage.getBoundingClientRect();
    const heroX = clamp((event.clientX - heroBounds.left) / heroBounds.width);
    const heroY = clamp((event.clientY - heroBounds.top) / heroBounds.height);
    const stageX = clamp((event.clientX - stageBounds.left) / stageBounds.width);
    const stageY = clamp((event.clientY - stageBounds.top) / stageBounds.height);
    lightX = heroX * 100;
    lightY = heroY * 100;
    tiltX = (stageX - 0.5) * 3;
    tiltY = (0.5 - stageY) * 2.5;
    queuePaint();
  });

  hero.addEventListener("pointerleave", () => {
    lightX = 72;
    lightY = 32;
    tiltX = 0;
    tiltY = 0;
    queuePaint();
  });
}

function setMenu(open) {
  if (!menuButton || !siteNav) return;
  menuButton.setAttribute("aria-expanded", String(open));
  menuButton.querySelector(".menu-label").textContent = open ? "Close" : "Menu";
  siteNav.classList.toggle("is-open", open);
}

menuButton?.addEventListener("click", () => {
  setMenu(menuButton.getAttribute("aria-expanded") !== "true");
});

siteNav?.addEventListener("click", (event) => {
  if (event.target.closest("a")) setMenu(false);
});

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") setMenu(false);
});

function announce(message) {
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add("is-visible");
  window.setTimeout(() => toast.classList.remove("is-visible"), 2400);
}

async function copyText(text) {
  if (navigator.clipboard?.writeText) {
    await navigator.clipboard.writeText(text);
    return;
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.select();
  const copied = document.execCommand("copy");
  textarea.remove();
  if (!copied) throw new Error("Copy was not available");
}

document.querySelectorAll("[data-copy-command]").forEach((button) => {
  button.addEventListener("click", async () => {
    const originalLabel = button.textContent;
    button.disabled = true;
    button.textContent = "Copying";
    try {
      await copyText(button.dataset.copyCommand);
      button.textContent = "Copied";
      announce("Build command copied.");
    } catch {
      button.textContent = "Try again";
      announce("Could not copy the command.");
    } finally {
      window.setTimeout(() => {
        button.textContent = originalLabel;
        button.disabled = false;
      }, 1800);
    }
  });
});

const year = document.querySelector("[data-year]");
if (year) year.textContent = String(new Date().getFullYear());
