import { Controller } from "@hotwired/stimulus"

// Adds scope tags to a text input from clickable buttons.
// Usage:
//   <div data-controller="scope-adder">
//     <input data-scope-adder-target="input" ...>
//     <button data-action="scope-adder#add" data-scope="read:users">+ read:users</button>
//   </div>
export default class extends Controller {
  static targets = ["input"]

  add(event) {
    const button = event.currentTarget
    const scope = button.dataset.scope
    const currentScopes = this.inputTarget.value
      .split(",")
      .map(s => s.trim())
      .filter(s => s.length > 0)

    if (!currentScopes.includes(scope)) {
      currentScopes.push(scope)
      this.inputTarget.value = currentScopes.join(", ")
      button.classList.add("opacity-50", "cursor-not-allowed")
      button.disabled = true
    }
  }
}
