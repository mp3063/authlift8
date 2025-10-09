import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    // Auto-dismiss flash messages after 5 seconds
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  dismiss(event) {
    if (event) {
      event.preventDefault()
    }

    const message = event?.currentTarget?.closest('[data-flash-target="message"]') || this.messageTarget

    message.style.transition = "opacity 0.3s ease-out"
    message.style.opacity = "0"

    setTimeout(() => {
      message.remove()
    }, 300)

    clearTimeout(this.timeout)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
