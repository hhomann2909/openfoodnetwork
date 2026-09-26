import { Controller } from "stimulus";

// Brings the product named in ?product= into view in the shop's product grid and marks it
// briefly, for visitors coming from a product tile on the home page.
export default class extends Controller {
  connect() {
    const id = new URLSearchParams(window.location.search).get("product");
    if (!id || !/^\d+$/.test(id)) return;

    const link = this.element.querySelector(`[data-modal-link-target-value="product-modal-${id}"]`);
    const tile = link?.closest(".product-item");
    if (!tile) return;

    tile.classList.add("is-focused");
    tile.scrollIntoView({ block: "center", behavior: this.#behavior() });
    tile.querySelector(".variant button, .variant input")?.focus({ preventScroll: true });
    setTimeout(() => tile.classList.remove("is-focused"), 4000);
  }

  #behavior() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth";
  }
}
