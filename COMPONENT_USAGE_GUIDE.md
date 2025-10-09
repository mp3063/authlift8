# ViewComponent Usage Guide

A quick reference for using Authlift's ViewComponents in your views.

---

## UI Components

### ButtonComponent

**Basic Usage:**
```erb
<%= render UI::ButtonComponent.new do %>
  Click Me
<% end %>
```

**With Variants:**
```erb
<!-- Primary button (default) -->
<%= render UI::ButtonComponent.new(variant: :primary) do %>
  Save Changes
<% end %>

<!-- Secondary button -->
<%= render UI::ButtonComponent.new(variant: :secondary) do %>
  Cancel
<% end %>

<!-- Danger button -->
<%= render UI::ButtonComponent.new(variant: :danger) do %>
  Delete Account
<% end %>

<!-- Success button -->
<%= render UI::ButtonComponent.new(variant: :success) do %>
  Approve
<% end %>

<!-- Outline button -->
<%= render UI::ButtonComponent.new(variant: :outline) do %>
  Learn More
<% end %>

<!-- Ghost button -->
<%= render UI::ButtonComponent.new(variant: :ghost) do %>
  Skip
<% end %>
```

**With Sizes:**
```erb
<!-- Small -->
<%= render UI::ButtonComponent.new(size: :sm) do %>
  Small Button
<% end %>

<!-- Medium (default) -->
<%= render UI::ButtonComponent.new(size: :md) do %>
  Medium Button
<% end %>

<!-- Large -->
<%= render UI::ButtonComponent.new(size: :lg) do %>
  Large Button
<% end %>
```

**With HTML Options:**
```erb
<%= render UI::ButtonComponent.new(
  variant: :primary,
  size: :lg,
  type: "submit",
  disabled: false,
  class: "w-full",
  data: { action: "click->modal#open" }
) do %>
  Submit Form
<% end %>
```

---

### CardComponent

**Basic Usage:**
```erb
<%= render UI::CardComponent.new do %>
  Card content goes here
<% end %>
```

**With Header:**
```erb
<%= render UI::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h2 class="text-lg font-semibold">Card Title</h2>
  <% end %>

  Card body content
<% end %>
```

**With Header and Footer:**
```erb
<%= render UI::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h2 class="text-lg font-semibold">Settings</h2>
  <% end %>

  <p>Your settings content here</p>

  <% card.with_footer do %>
    <div class="flex justify-end space-x-2">
      <%= render UI::ButtonComponent.new(variant: :secondary) do %>
        Cancel
      <% end %>
      <%= render UI::ButtonComponent.new(variant: :primary) do %>
        Save
      <% end %>
    </div>
  <% end %>
<% end %>
```

**Without Padding or Shadow:**
```erb
<%= render UI::CardComponent.new(padding: false, shadow: false) do %>
  Custom content without padding
<% end %>
```

---

### ModalComponent

**Basic Usage:**
```erb
<%= render UI::ModalComponent.new(id: "my-modal") do |modal| %>
  <% modal.with_header do %>
    Modal Title
  <% end %>

  Modal content goes here

  <% modal.with_footer do %>
    <%= render UI::ButtonComponent.new(
      variant: :primary,
      data: { action: "click->modal#close" }
    ) do %>
      Close
    <% end %>
  <% end %>
<% end %>
```

**Different Sizes:**
```erb
<!-- Small modal -->
<%= render UI::ModalComponent.new(id: "small-modal", size: :sm) do %>
  Small modal content
<% end %>

<!-- Medium modal (default) -->
<%= render UI::ModalComponent.new(id: "medium-modal", size: :md) do %>
  Medium modal content
<% end %>

<!-- Large modal -->
<%= render UI::ModalComponent.new(id: "large-modal", size: :lg) do %>
  Large modal content
<% end %>

<!-- Extra large modal -->
<%= render UI::ModalComponent.new(id: "xl-modal", size: :xl) do %>
  XL modal content
<% end %>

<!-- Full width modal -->
<%= render UI::ModalComponent.new(id: "full-modal", size: :full) do %>
  Full width modal content
<% end %>
```

**Opening a Modal (with Stimulus):**
```erb
<!-- Trigger button -->
<button data-action="click->modal#open" data-modal-target="#my-modal">
  Open Modal
</button>

<!-- Or using ButtonComponent -->
<%= render UI::ButtonComponent.new(
  data: { action: "click->modal#open", modal_target: "#my-modal" }
) do %>
  Open Modal
<% end %>
```

---

## Shared Components

### NavbarComponent

**Usage in Layout:**
```erb
<!-- app/views/layouts/application.html.erb -->
<% if user_signed_in? %>
  <%= render Shared::NavbarComponent.new(current_user: current_user) %>
<% end %>
```

---

### FlashComponent

**Usage in Layout:**
```erb
<!-- app/views/layouts/application.html.erb -->
<%= render Shared::FlashComponent.new(flash: flash) %>
```

**Setting Flash Messages in Controllers:**
```ruby
# Success
flash[:success] = "Account created successfully!"
flash[:notice] = "Changes saved."

# Errors
flash[:error] = "Something went wrong."
flash[:alert] = "You must be logged in."

# Warnings and Info
flash[:warning] = "Your subscription expires soon."
flash[:info] = "New features available!"
```

---

### FormErrorsComponent

**Usage in Forms:**
```erb
<%= form_for @user do |f| %>
  <%= render Shared::FormErrorsComponent.new(model: @user) %>

  <!-- Form fields -->
<% end %>
```

**The component automatically:**
- Checks if the model has errors
- Displays error count
- Lists all validation errors
- Only renders if errors are present

---

## Stimulus Controllers

### Dropdown Controller

**Usage:**
```erb
<div data-controller="dropdown">
  <!-- Trigger button -->
  <button data-action="click->dropdown#toggle">
    Open Menu
  </button>

  <!-- Dropdown menu -->
  <div data-dropdown-target="menu" class="hidden">
    <a href="#">Menu Item 1</a>
    <a href="#">Menu Item 2</a>
  </div>
</div>
```

**Features:**
- Toggles menu visibility
- Closes when clicking outside
- Removes event listeners on disconnect

---

### Flash Controller

**Usage:**
```erb
<div data-controller="flash">
  <div data-flash-target="message">
    Flash message content
    <button data-action="click->flash#dismiss">×</button>
  </div>
</div>
```

**Features:**
- Auto-dismisses after 5 seconds
- Manual dismiss with button
- Fade-out animation

---

### Modal Controller

**Usage:**
```erb
<!-- Modal -->
<div id="my-modal" data-controller="modal" class="hidden">
  <!-- Modal content -->
</div>

<!-- Trigger -->
<button data-action="click->modal#open">Open</button>

<!-- Close button inside modal -->
<button data-action="click->modal#close">Close</button>
```

**Features:**
- Opens/closes modal
- Locks body scroll when open
- Closes on Escape key
- Closes on backdrop click

---

## Complete Examples

### Login Form

```erb
<%= render UI::CardComponent.new(shadow: true) do |card| %>
  <%= form_for(resource, url: session_path(resource_name)) do |f| %>
    <%= render Shared::FormErrorsComponent.new(model: resource) %>

    <div class="space-y-4">
      <div>
        <%= f.label :email, class: "block text-sm font-medium text-gray-700" %>
        <%= f.email_field :email,
            class: "mt-1 block w-full rounded-lg border border-gray-300 px-3 py-2" %>
      </div>

      <div>
        <%= f.label :password, class: "block text-sm font-medium text-gray-700" %>
        <%= f.password_field :password,
            class: "mt-1 block w-full rounded-lg border border-gray-300 px-3 py-2" %>
      </div>

      <%= render UI::ButtonComponent.new(
        variant: :primary,
        type: "submit",
        class: "w-full"
      ) do %>
        Sign In
      <% end %>
    </div>
  <% end %>
<% end %>
```

### Confirmation Modal

```erb
<%= render UI::ModalComponent.new(id: "confirm-delete", size: :sm) do |modal| %>
  <% modal.with_header do %>
    Confirm Deletion
  <% end %>

  <p class="text-sm text-gray-600">
    Are you sure you want to delete this item? This action cannot be undone.
  </p>

  <% modal.with_footer do %>
    <div class="flex space-x-2 justify-end">
      <%= render UI::ButtonComponent.new(
        variant: :secondary,
        data: { action: "click->modal#close" }
      ) do %>
        Cancel
      <% end %>

      <%= render UI::ButtonComponent.new(
        variant: :danger,
        type: "submit"
      ) do %>
        Delete
      <% end %>
    </div>
  <% end %>
<% end %>
```

### Settings Page

```erb
<div class="max-w-3xl mx-auto space-y-6">
  <h1 class="text-3xl font-bold">Settings</h1>

  <%= render UI::CardComponent.new(shadow: true) do |card| %>
    <% card.with_header do %>
      <h2 class="text-lg font-semibold">Profile Information</h2>
    <% end %>

    <%= form_for @user do |f| %>
      <%= render Shared::FormErrorsComponent.new(model: @user) %>

      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div>
            <%= f.label :first_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :first_name,
                class: "mt-1 block w-full rounded-lg border px-3 py-2" %>
          </div>

          <div>
            <%= f.label :last_name, class: "block text-sm font-medium text-gray-700" %>
            <%= f.text_field :last_name,
                class: "mt-1 block w-full rounded-lg border px-3 py-2" %>
          </div>
        </div>
      </div>
    <% end %>

    <% card.with_footer do %>
      <div class="flex justify-end space-x-2">
        <%= render UI::ButtonComponent.new(variant: :secondary) do %>
          Cancel
        <% end %>
        <%= render UI::ButtonComponent.new(variant: :primary, type: "submit") do %>
          Save Changes
        <% end %>
      </div>
    <% end %>
  <% end %>
</div>
```

---

## Tips

1. **Always use ERB** - No HAML in this project
2. **Use Tailwind classes** - No custom CSS needed
3. **Keep components simple** - Small, focused, reusable
4. **Use slots for flexibility** - Header/footer slots in cards and modals
5. **Leverage Stimulus** - For interactive behaviors
6. **Follow accessibility** - Always include labels, ARIA attributes
7. **Mobile-first** - Use responsive Tailwind classes (sm:, md:, lg:)

---

## Further Reading

- [ViewComponent Documentation](https://viewcomponent.org/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Stimulus Handbook](https://stimulus.hotwired.dev/)
- [Heroicons](https://heroicons.com/)

