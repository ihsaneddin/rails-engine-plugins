# Plugins

`Plugins` is the shared foundation engine used by the other VirtualSpirit engines.

It exists to solve one repeated problem across engine development:

- each engine needs the same kinds of extensibility points
- each engine needs a consistent way to expose model behavior to Rails controllers and Grape APIs
- each engine needs shared configuration, callback, event, and decorator primitives

Without a shared layer, each engine would rebuild its own DSLs for:

- API resource configuration
- Grape endpoint configuration
- callback registration
- permission registration
- event publishing and subscription
- inheritable class configuration
- traits, decorators, and method annotations

`Plugins` centralizes those primitives so sibling engines can stay focused on domain behavior instead of rebuilding infrastructure.

## What Problem This Solves

Use this engine when you are building another engine or app module that needs all of these at the same time:

- configurable model-to-API exposure
- reusable controller and Grape behavior
- structured callbacks and permissions
- event bus publishing/subscription
- inheritable DSLs for decorators and model concerns

Why this matters:

- a domain engine should define business behavior
- the shared engine should define how that behavior is configured, exposed, decorated, and reused

`Plugins` is that shared engine.

## How The Engine Works

The engine has four main layers:

- configuration
- decorators
- model concerns
- controller and Grape concerns

Think of them this way:

- configuration answers "how should this engine or endpoint behave?"
- decorators answer "how should classes and methods gain reusable behavior?"
- model concerns answer "how should models expose API, event, and custom attribute behavior?"
- controller/Grape concerns answer "how should Rails and Grape endpoints resolve resources and respond consistently?"

## Configuration Layer

The configuration layer provides shared modules under `Plugins::Configuration`:

- `Core`
- `Api`
- `GrapeApi`
- `Callbacks`
- `Permissions`
- `Events`
- `Bus`

These are used by sibling engines to build configuration DSLs without duplicating setup logic.

Example:

```ruby
module PaymentCore
  module Configuration
    include Plugins::Configuration::Core
  end
end
```

That gives the engine shared setup points for:

- `events`
- `api`
- `grape_api`
- `permission_set_class`
- `permission_class`
- `bus`

### API and Grape API Config

`Plugins::Configuration::Api` and `Plugins::Configuration::GrapeApi` provide common endpoint setup such as:

- authentication
- authorization
- pagination config
- callback drawing
- base namespace / base endpoint registration

Example:

```ruby
Plugins.config.api.setup do
  authenticate! { current_user }
end

Plugins.config.grape_api.setup do
  authenticate! { current_user }
  authorize! { |*args| true }
end
```

### Callback Config

`Plugins::Configuration::Callbacks` provides a way to register endpoint behavior declaratively and attach it later to matching classes.

That is what powers engine-level callback drawing for Rails controllers and Grape endpoints.

### Permissions Config

`Plugins::Configuration::Permissions` provides a DSL for defining permissions and grouping them into nested permission sets.

This is the shared permission registry mechanism used by engines that want structured permission declaration instead of ad hoc checks.

### Events and Bus

`Plugins::Configuration::Events` wraps `ActiveSupport::Notifications`.

`Plugins::Configuration::Bus` wraps `Omnes::Bus` and is used by the Eventable concerns for:

- registering events
- publishing events
- subscribing to events
- subscribing with matchers or all-events handlers

## Decorator Layer

The decorator layer provides reusable primitives under `Plugins::Decorators`:

- `Inheritables`
- `Registered`
- `Traits`
- `ConfigBuilder`
- `SmartSend`
- `MethodAnnotations`
- `MethodDecorators`
- `Hooks`

These modules let engines create their own thin DSLs while still sharing inheritance and registration behavior.

### Inheritables

`Inheritables` gives classes inheritable class attributes and inheritable singleton methods with deep-copy semantics.

Use this when:

- subclass configuration should not mutate the parent
- a DSL-defined singleton method should survive inheritance

### Registered

`Registered` keeps track of registered classes in a copy-on-write set.

Use this when a concern or decorator needs to remember which classes have opted in.

### Traits

`Traits` layers trait registration on top of registered classes and can define trait flag methods or trait class methods on registered hosts.

### SmartSend

`SmartSend` normalizes positional and keyword dispatch to methods referenced by symbols or DSL configuration.

This matters because many config objects in this engine evaluate symbols, procs, and unbound methods against a runtime context.

### MethodAnnotations and MethodDecorators

These modules support attaching metadata to methods and wrapping methods with reusable decorators.

That lets sibling engines define behaviors such as:

- publish an event after a method succeeds
- store method annotations for later reflection
- attach reusable wrappers without hand-rolling alias chains

## Model Concerns Layer

The model concern layer provides shared building blocks under `Plugins::Models::Concerns`.

Common examples:

- `ApiResource`
- `Config`
- `Eventable`
- `CustomAttributes`
- `AssociationHelpers`
- `ActsAsDefaultValue`

### Config

`Plugins::Models::Concerns::Config` is the core config object used across the engine.

It supports:

- known-key config objects
- nested config objects
- dynamic config collections
- runtime evaluation against a context
- shallow merge and deep merge

This is the base primitive behind API resource config, action config, and other DSL-backed objects.

### ApiResource

`ApiResource` lets a model declare per-context API behavior for Rails or Grape consumers.

It supports:

- `api_resource`
- `grape_api_resource`
- per-context lookup with `*_api_resource_of(context)`
- action collections
- resource finder and params config
- presenter selection

Example:

```ruby
class PaymentMethod < ApplicationRecord
  include Plugins::Models::Concerns::ApiResource

  grape_api_resource "payment_core", default: true do
    presenter "PaymentCore::Grape::Presenters::PaymentMethod"
    resource_identifier :id
  end

  grape_api_resource "app", from: "payment_core" do
    presenter "App::Grape::Presenters::PaymentMethod"
  end
end
```

In that example:

- `"payment_core"` is the base Grape resource config
- `"app"` clones the `"payment_core"` config
- the `"app"` block overrides only what it needs

That means host apps can inherit an engine-defined API resource config and override it without rewriting the whole resource definition.

### Eventable

`Eventable` gives models a shared event publication and subscription layer.

The two main parts are:

- `Eventable::PublishesEvents`
- `Eventable::SubscribesToEvents`

This is where `Plugins::Configuration::Bus` is used in actual model behavior.

Example publication:

```ruby
publishes_event :completed, on: :complete!
```

Example subscription:

```ruby
on_event :payment_completed, bus: :payments do |event|
  # handle event
end
```

### CustomAttributes

`CustomAttributes` provides a structured way to define typed custom attributes and their behavior once, then reuse them across models.

## Controller and Grape Layer

The controller and Grape layers provide shared endpoint concerns for engines that expose HTTP APIs.

Rails controller concerns live under:

- `Plugins::Controllers::Concerns`

Grape concerns and presenters live under:

- `Plugins::Grape::Concerns`
- `Plugins::Grape::Presenters`

These shared layers handle things like:

- authentication
- authorization
- pagination
- resourceful loading
- responder behavior
- presenter selection

This lets sibling engines use the same endpoint behavior model instead of hand-coding those flows in each engine.

## Root Engine Usage Pattern

A sibling engine usually uses `Plugins` in a few predictable places:

- include configuration core in its config module
- include model concerns in its decorated models
- include controller/Grape concerns in endpoint base classes
- use decorators to define inheritable DSLs and hooks

Typical example:

```ruby
module MyEngine
  module Configuration
    include Plugins::Configuration::Core
  end
end

class MyRecord < ApplicationRecord
  include Plugins::Models::Concerns::ApiResource
  include Plugins::Models::Concerns::Eventable::PublishesEvents
end
```

## Installation

Add the engine to the host app or sibling engine:

```ruby
gem "plugins", path: "../plugins"
```

Install dependencies:

```bash
bundle install
```

## Development

Install the local development and test dependencies:

```bash
bundle install
```

Run the current targeted spec suite:

```bash
bundle exec rspec spec/plugins spec/models/plugins/concerns/config_spec.rb spec/models/plugins/concerns/api_resource_spec.rb
```

The engine also includes a dummy app under `spec/dummy` for support constants and integration-oriented specs.

## Notes

- `Plugins` is primarily an infrastructure engine, not a domain engine.
- Most host engines should depend on its public DSLs and wrappers, not its internal implementation details.
- When fixing behavior inside this engine, preserve wrapper boundaries where possible. For example, `Plugins::Configuration::Bus` should own bus-specific compatibility logic instead of leaking those details into callers.

## Contributing

Bug reports and pull requests are welcome.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
