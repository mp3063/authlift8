import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "backdrop"]

  open() {
    this.drawerTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")

    const firstFocusable = this.drawerTarget.querySelector("a, button")
    if (firstFocusable) firstFocusable.focus()
  }

  close() {
    this.drawerTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  connect() {
    this._boundEscape = this._closeOnEscape.bind(this)
    document.addEventListener("keydown", this._boundEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this._boundEscape)
    document.body.classList.remove("overflow-hidden")
  }

  _closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
