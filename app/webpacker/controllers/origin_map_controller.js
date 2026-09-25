import { Controller } from "stimulus";
import L from "leaflet";
import "leaflet-providers";

// The origin map (feature: origin_map): producers and pick-up points, joined by the routes of
// open order cycles. The list beside the map is rendered on the server; this controller draws
// the map from the same data and keeps both in step.
export default class extends Controller {
  static targets = ["map", "item", "country", "tab"];
  static values = { points: Array, routes: Array, tiles: String, labels: Object };

  connect() {
    this.pointsById = new Map(this.pointsValue.map((point) => [point.id, point]));
    this.markers = new Map();
    this.routeLines = [];
    this.country = "";

    this.map = L.map(this.mapTarget, { zoomControl: false, scrollWheelZoom: false });
    L.control.zoom({ position: "bottomright" }).addTo(this.map);
    this.#tileLayer().addTo(this.map);
    // Scroll-zoom only once the map has focus, so the page itself still scrolls.
    this.map.on("click", () => this.map.scrollWheelZoom.enable());
    this.map.on("mouseout", () => this.map.scrollWheelZoom.disable());

    this.#drawRoutes();
    this.#drawMarkers();
    this.#fitToVisible();

    // The map can get its size only after connect: phone layout, fonts, or a page opened in a
    // background tab. Resize with it, and fit to the markers once it first has a size.
    this.resizeObserver = new ResizeObserver(() => {
      this.map.invalidateSize();
      if (!this.fitted) this.#fitToVisible();
    });
    this.resizeObserver.observe(this.mapTarget);
  }

  disconnect() {
    this.resizeObserver?.disconnect();
    this.map?.remove();
  }

  // Panel actions

  focus(event) {
    const point = this.pointsById.get(Number(event.currentTarget.closest("li").dataset.id));
    const marker = this.markers.get(point.id);
    if (!marker) return;

    this.map.flyTo(marker.getLatLng(), Math.max(this.map.getZoom(), 8), { duration: 0.6 });
    marker.openPopup();
  }

  highlight(event) {
    this.#highlightRoutes(Number(event.currentTarget.closest("li").dataset.id));
  }

  unhighlight() {
    this.#highlightRoutes(null);
  }

  showTab(event) {
    const kind = event.currentTarget.dataset.kind;
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-selected", tab.dataset.kind === kind));
    this.kind = kind;
    this.#applyFilters();
  }

  filterCountry(event) {
    this.country = event.currentTarget.dataset.country;
    this.countryTargets.forEach((chip) =>
      chip.setAttribute("aria-pressed", chip.dataset.country === this.country),
    );
    this.#applyFilters();
    this.#fitToVisible();
  }

  // Drawing

  #tileLayer() {
    try {
      return L.tileLayer.provider(this.tilesValue || "OpenStreetMap.Mapnik");
    } catch {
      return L.tileLayer.provider("OpenStreetMap.Mapnik");
    }
  }

  #drawMarkers() {
    // Producers first, so pick-up points sit on top where they overlap.
    const points = [...this.pointsValue].sort((a, b) => (a.kind === "shop") - (b.kind === "shop"));
    points.forEach((point) => {
      const marker = L.marker([point.lat, point.lng], {
        icon: this.#icon(point),
        title: point.name,
        riseOnHover: true,
      });
      marker.bindPopup(() => this.#popup(point), { maxWidth: 280, className: "origin-map-popup" });
      marker.on("mouseover", () => this.#highlightRoutes(point.id));
      marker.on("mouseout", () => this.#highlightRoutes(null));
      marker.addTo(this.map);
      this.markers.set(point.id, marker);
    });
  }

  #icon(point) {
    if (point.kind === "shop") {
      return L.divIcon({
        className: "origin-map-marker is-shop",
        html: `<svg viewBox="0 0 28 36" aria-hidden="true"><path d="M14 35s12-11.6 12-21A12 12 0 0 0 2 14c0 9.4 12 21 12 21z"/><circle cx="14" cy="14" r="4.5"/></svg>`,
        iconSize: [28, 36],
        iconAnchor: [14, 35],
        popupAnchor: [0, -30],
      });
    }
    return L.divIcon({
      className: "origin-map-marker is-producer",
      html: "<span></span>",
      iconSize: [20, 20],
      iconAnchor: [10, 10],
      popupAnchor: [0, -10],
    });
  }

  #drawRoutes() {
    this.routesValue.forEach((route) => {
      const from = this.pointsById.get(route.from);
      const to = this.pointsById.get(route.to);
      if (!from || !to) return;

      const line = L.polyline(this.#arc(from, to), {
        className: "origin-map-route",
        interactive: false,
        smoothFactor: 1,
      }).addTo(this.map);
      this.routeLines.push({ route, line });
    });
  }

  // A gentle arc from producer to pick-up point, bending to the right of the direction of
  // travel so routes from one region fan out instead of lying on top of each other.
  #arc(from, to, steps = 32) {
    const [x1, y1, x2, y2] = [from.lng, from.lat, to.lng, to.lat];
    const [mx, my] = [(x1 + x2) / 2, (y1 + y2) / 2];
    const [dx, dy] = [x2 - x1, y2 - y1];
    const [cx, cy] = [mx + dy * 0.18, my - dx * 0.18];

    return Array.from({ length: steps + 1 }, (_, index) => {
      const t = index / steps;
      const lng = (1 - t) ** 2 * x1 + 2 * (1 - t) * t * cx + t ** 2 * x2;
      const lat = (1 - t) ** 2 * y1 + 2 * (1 - t) * t * cy + t ** 2 * y2;
      return [lat, lng];
    });
  }

  #highlightRoutes(id) {
    this.routeLines.forEach(({ route, line }) => {
      const element = line.getElement();
      if (!element) return;
      const active = id !== null && (route.from === id || route.to === id);
      element.classList.toggle("is-active", active);
      element.classList.toggle("is-dimmed", id !== null && !active);
    });
  }

  #popup(point) {
    const labels = this.labelsValue;
    const routes = this.routesValue.filter((route) =>
      point.kind === "shop" ? route.to === point.id : route.from === point.id,
    );
    const others = [
      ...new Set(
        routes.map((route) => this.pointsById.get(point.kind === "shop" ? route.from : route.to)),
      ),
    ].filter(Boolean);

    const parts = [
      `<div class="origin-map-popup-kind is-${point.kind}">${escape(labels[point.kind])}</div>`,
      `<strong class="origin-map-popup-name">${escape(point.name)}</strong>`,
      `<div class="origin-map-popup-place">${escape(point.place)}</div>`,
    ];

    if (point.kind === "producer" && point.products?.length) {
      parts.push(
        `<div class="origin-map-popup-label">${escape(labels.on_sale)}</div>`,
        `<ul>${point.products.map((name) => `<li>${escape(name)}</li>`).join("")}</ul>`,
      );
    }

    if (others.length) {
      const label = point.kind === "shop" ? labels.supplied_by : labels.goes_to;
      const names = others.map((other) => escape(other.name)).join(", ");
      parts.push(`<div class="origin-map-popup-label">${escape(label)}</div><p>${names}</p>`);
    }

    const pallet = routes.find((route) => route.pallet_fill !== null);
    if (pallet) {
      const status = pallet.pallet_confirmed ? ` · ${escape(labels.confirmed)}` : "";
      parts.push(
        `<div class="origin-map-popup-pallet${pallet.pallet_confirmed ? " is-confirmed" : ""}">` +
          `<span>${escape(labels.pallet)} ${pallet.pallet_fill}%${status}</span>` +
          `<span class="bar"><span style="width: ${pallet.pallet_fill}%"></span></span></div>`,
      );
    }

    if (point.kind === "shop") {
      parts.push(
        point.open
          ? `<a class="origin-map-popup-button" href="${escape(point.shop_url)}">${escape(labels.order)}</a>`
          : `<div class="origin-map-popup-closed">${escape(labels.closed)}</div>`,
      );
    }

    return parts.join("");
  }

  // Filters

  #applyFilters() {
    const kind = this.kind || "producer";
    this.itemTargets.forEach((item) => {
      item.hidden = item.dataset.kind !== kind || !this.#inCountry(item.dataset.country);
    });

    this.markers.forEach((marker, id) => {
      const visible = this.#inCountry(this.pointsById.get(id).country);
      if (visible && !this.map.hasLayer(marker)) marker.addTo(this.map);
      if (!visible && this.map.hasLayer(marker)) marker.remove();
    });

    this.routeLines.forEach(({ route, line }) => {
      const visible =
        this.#inCountry(this.pointsById.get(route.from).country) ||
        this.#inCountry(this.pointsById.get(route.to).country);
      line.getElement()?.classList.toggle("is-hidden", !visible);
    });
  }

  #inCountry(country) {
    return !this.country || country === this.country;
  }

  #fitToVisible() {
    // Without a size Leaflet would zoom all the way in; wait for the next fit instead.
    const size = this.map.getSize();
    if (size.x === 0 || size.y === 0) return;
    this.fitted = true;

    const latLngs = [...this.markers.values()]
      .filter((marker) => this.map.hasLayer(marker))
      .map((marker) => marker.getLatLng());
    if (latLngs.length === 0) {
      this.map.setView([48, 10], 4);
    } else if (latLngs.length === 1) {
      this.map.setView(latLngs[0], 9);
    } else {
      this.map.fitBounds(L.latLngBounds(latLngs), { padding: [48, 48] });
    }
  }
}

function escape(text) {
  const element = document.createElement("span");
  element.textContent = text ?? "";
  return element.innerHTML.replace(/"/g, "&quot;");
}
