// Search the pages in this manual without relying on Racket's global search site.
document.addEventListener("DOMContentLoaded", () => {
  const placeholder = document.querySelector(".navsettop .nosearchform");
  const sidebar = document.querySelector(".tocset .tocview");
  if (!placeholder || !sidebar) return;

  const form = document.createElement("form");
  form.className = "site-search searchform";
  form.setAttribute("role", "search");
  const input = document.createElement("input");
  input.className = "searchbox";
  input.type = "search";
  input.placeholder = "Search ScienceLogo";
  input.setAttribute("aria-label", "Search ScienceLogo documentation");
  form.append(input);
  placeholder.replaceWith(form);

  const results = document.createElement("div");
  results.className = "site-search-results";
  results.setAttribute("role", "region");
  results.setAttribute("aria-label", "Documentation search results");
  results.setAttribute("aria-live", "polite");
  results.hidden = true;
  form.after(results);

  let pagesPromise;
  function loadPages() {
    if (!pagesPromise) {
      const links = [...sidebar.querySelectorAll("a.tocviewlink, a.tocviewselflink")];
      const unique = new Map();
      for (const link of links) {
        const url = new URL(link.href, location.href);
        if (url.hash || unique.has(url.href)) continue;
        unique.set(url.href, { url, title: link.textContent.trim() });
      }
      pagesPromise = Promise.all([...unique.values()].map(async (page) => {
        try {
          const response = await fetch(page.url);
          if (!response.ok) return null;
          const html = new DOMParser().parseFromString(await response.text(), "text/html");
          const section = html.querySelector(".maincolumn .main section");
          return section ? { ...page, text: section.textContent.replace(/\s+/g, " ").trim() } : null;
        } catch (_) {
          return null;
        }
      }));
    }
    return pagesPromise;
  }

  function showMessage(message) {
    results.replaceChildren();
    const paragraph = document.createElement("p");
    paragraph.textContent = message;
    results.append(paragraph);
    results.hidden = false;
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const terms = input.value.trim().toLocaleLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.length) {
      results.hidden = true;
      return;
    }
    showMessage("Searching…");
    const pages = (await loadPages()).filter(Boolean);
    if (!pages.length) {
      showMessage("Search is unavailable. Try your browser's Find command.");
      return;
    }
    const matches = pages.filter((page) =>
      terms.every((term) => page.text.toLocaleLowerCase().includes(term)));
    results.replaceChildren();
    const heading = document.createElement("p");
    heading.textContent = matches.length
      ? `${matches.length} page${matches.length === 1 ? "" : "s"} found`
      : "No matching pages";
    results.append(heading);
    for (const page of matches) {
      const link = document.createElement("a");
      link.href = page.url.href;
      link.textContent = page.title;
      results.append(link);
      const offset = page.text.toLocaleLowerCase().indexOf(terms[0]);
      const snippet = document.createElement("p");
      snippet.textContent = `${offset > 45 ? "…" : ""}${page.text.slice(
        Math.max(0, offset - 45), Math.min(page.text.length, offset + 115)
      )}${offset + 115 < page.text.length ? "…" : ""}`;
      results.append(snippet);
    }
    results.hidden = false;
  });

  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") results.hidden = true;
  });
});
