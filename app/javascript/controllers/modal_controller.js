import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open() {
    this.element.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }

    this.element.classList.add("hidden")
    document.body.style.overflow = "auto"
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  connect() {
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("keydown", this.closeOnEscape)
    document.body.style.overflow = "auto"
  }
}
