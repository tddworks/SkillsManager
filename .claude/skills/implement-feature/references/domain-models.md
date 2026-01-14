# Rich Domain Model Patterns

## User's Mental Model

Domain models should match how users think about the domain. The key insight is that **objects own their data and behavior together**.

## Tell-Don't-Ask Principle

Instead of asking an object for data and acting on that data, tell the object what to do:

```swift
// BAD: Asking for data
for index in catalog.skills.indices {
    if catalog.skills[index].uniqueKey == uniqueKey {
        catalog.skills[index] = catalog.skills[index].withInstalledProviders(providers)
    }
}

// GOOD: Telling the object
catalog.updateInstallationStatus(for: uniqueKey, to: providers)
```

## Rich Domain Classes (Observable)

For stateful domain concepts that own collections, use `@Observable` classes:

```swift
@Observable
@MainActor
public final class SkillsCatalog: Identifiable {
    public let id: UUID
    public let url: String?
    public let name: String

    // Catalog OWNS its skills
    public var skills: [Skill] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    private let loader: SkillRepository

    // Tell-Don't-Ask: catalog manages its own skills
    public func loadSkills() async {
        isLoading = true
        do {
            skills = try await loader.fetchAll()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func addSkill(_ skill: Skill) {
        guard !skills.contains(where: { $0.uniqueKey == skill.uniqueKey }) else { return }
        skills.append(skill)
        skills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func removeSkill(uniqueKey: String) {
        skills.removeAll { $0.uniqueKey == uniqueKey }
    }

    public func updateInstallationStatus(for uniqueKey: String, to providers: Set<Provider>) {
        for index in skills.indices {
            if skills[index].uniqueKey == uniqueKey {
                skills[index] = skills[index].withInstalledProviders(providers)
            }
        }
    }
}
```

## Coordinating Classes

For classes that coordinate multiple domain objects:

```swift
@Observable
@MainActor
public final class SkillLibrary {
    // Library HAS catalogs
    public let localCatalog: SkillsCatalog
    public var remoteCatalogs: [SkillsCatalog] = []

    // Computed: all catalogs for iteration
    public var catalogs: [SkillsCatalog] {
        [localCatalog] + remoteCatalogs
    }

    // Computed: current catalog's skills filtered
    public var filteredSkills: [Skill] {
        selectedCatalog.skills.filter { $0.matches(query: searchQuery) }
    }

    // Tell catalogs what to do
    public func install(to providers: Set<Provider>) async {
        guard let skill = selectedSkill else { return }
        let updatedSkill = try await installer.install(skill, to: providers)

        // Tell each catalog to update
        localCatalog.updateInstallationStatus(for: skill.uniqueKey, to: updatedSkill.installedProviders)
        for catalog in remoteCatalogs {
            catalog.updateInstallationStatus(for: skill.uniqueKey, to: updatedSkill.installedProviders)
        }
    }
}
```

## Value Objects vs Behavior

```swift
// User thinks: "What's my order status?"
public struct Order: Sendable, Equatable {
    public let id: OrderId
    public let items: [OrderItem]
    public let status: OrderStatus
    public let createdAt: Date

    // User asks: "What's my total?"
    public var totalAmount: Decimal {
        items.reduce(0) { $0 + $1.subtotal }
    }

    // User asks: "Can I still cancel?"
    public var canBeCancelled: Bool {
        [.pending, .processing].contains(status)
    }

    // User asks: "How long ago was this?"
    public var ageDescription: String {
        // Human-readable format
        RelativeDateTimeFormatter().localizedString(for: createdAt, relativeTo: Date())
    }
}
```

## Behavior Over Data

Encapsulate domain rules in the model:

```swift
public struct ShoppingCart: Sendable, Equatable {
    public let items: [CartItem]
    public let appliedCoupon: Coupon?

    // Domain rule: total with discounts applied
    public var totalAmount: Decimal {
        let baseTotal = items.reduce(0) { $0 + $1.subtotal }
        let discount = appliedCoupon?.calculateDiscount(for: baseTotal) ?? 0
        return baseTotal - discount
    }

    // Domain rule: free shipping over threshold
    public var qualifiesForFreeShipping: Bool {
        totalAmount >= 50
    }

    // Domain rule: check if stale
    public var isStale: Bool {
        lastUpdated.timeIntervalSinceNow < -1800 // 30 minutes
    }

    // Immutable mutation - returns new instance
    public func adding(_ item: CartItem) -> ShoppingCart {
        ShoppingCart(items: items + [item], appliedCoupon: appliedCoupon)
    }

    public func applying(_ coupon: Coupon) -> Result<ShoppingCart, CartError> {
        guard appliedCoupon == nil else {
            return .failure(.couponAlreadyApplied)
        }
        guard coupon.isValid(for: self) else {
            return .failure(.couponNotValid)
        }
        return .success(ShoppingCart(items: items, appliedCoupon: coupon))
    }
}
```

## Protocols for Capabilities

Define protocols for what entities can do:

```swift
@Mockable
public protocol PaymentProcessor: Sendable {
    var id: String { get }
    var name: String { get }
    func isAvailable() async -> Bool
    func process(_ payment: Payment) async throws -> PaymentResult
    func refund(transactionId: String, amount: Decimal) async throws -> RefundResult
}

@Mockable
public protocol Repository: Sendable {
    associatedtype Entity
    associatedtype ID

    func findById(_ id: ID) async throws -> Entity?
    func save(_ entity: Entity) async throws
    func delete(_ id: ID) async throws
}
```

## Value Types for Data

Use structs for immutable data with behavior:

```swift
public struct Money: Sendable, Equatable, Hashable, Comparable {
    public let amount: Decimal
    public let currency: Currency

    // Computed behavior
    public var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.code
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency.symbol)\(amount)"
    }

    // Operations return new instances (immutable)
    public func adding(_ other: Money) -> Money {
        precondition(currency == other.currency)
        return Money(amount: amount + other.amount, currency: currency)
    }

    public func multiplying(by factor: Decimal) -> Money {
        Money(amount: amount * factor, currency: currency)
    }

    // Comparable
    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency)
        return lhs.amount < rhs.amount
    }
}

public struct Address: Sendable, Equatable, Hashable {
    public let street: String
    public let city: String
    public let country: String
    public let postalCode: String

    public var formatted: String {
        "\(street), \(city), \(postalCode), \(country)"
    }

    public func isInternational(from homeCountry: String) -> Bool {
        country != homeCountry
    }
}
```

## Enums for States

Use enums with behavior for finite states:

```swift
public enum OrderStatus: Int, Comparable, Sendable, CaseIterable {
    case pending = 0
    case processing = 1
    case shipped = 2
    case delivered = 3
    case cancelled = 4

    public var needsAttention: Bool {
        self <= .processing
    }

    public var displayColor: Color {
        switch self {
        case .pending: return .yellow
        case .processing: return .blue
        case .shipped: return .purple
        case .delivered: return .green
        case .cancelled: return .red
        }
    }

    public var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .shipped: return "Shipped"
        case .delivered: return "Delivered"
        case .cancelled: return "Cancelled"
        }
    }

    public var isTerminal: Bool {
        self == .delivered || self == .cancelled
    }

    public static func < (lhs: OrderStatus, rhs: OrderStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
```

## Actors for Thread Safety

Use actors for stateful domain services:

```swift
public actor OrderManager {
    private let repository: any OrderRepository
    private var cachedOrders: [OrderId: Order] = [:]

    public init(repository: any OrderRepository) {
        self.repository = repository
    }

    public func getOrder(_ id: OrderId) async throws -> Order {
        if let cached = cachedOrders[id] {
            return cached
        }
        let order = try await repository.fetch(id: id)
        cachedOrders[id] = order
        return order
    }

    public func updateStatus(_ id: OrderId, to status: OrderStatus) async throws {
        var order = try await getOrder(id)
        order = order.withStatus(status)
        try await repository.save(order)
        cachedOrders[id] = order
    }

    public func refreshAll() async {
        cachedOrders.removeAll()
    }
}
```

## Factory Methods

Use static methods for complex construction:

```swift
extension Order {
    public static func fromCheckout(cart: ShoppingCart, customer: Customer) -> Order {
        let items = cart.items.map { cartItem in
            OrderItem(
                productId: cartItem.productId,
                price: cartItem.price,
                quantity: cartItem.quantity
            )
        }
        return Order(
            id: OrderId(),
            items: items,
            status: .pending,
            createdAt: Date()
        )
    }

    public static func fromPersistence(_ data: OrderData) throws -> Order {
        // Map persistence data to domain model
        guard let status = OrderStatus(rawValue: data.statusRaw) else {
            throw DomainError.invalidData
        }
        return Order(
            id: OrderId(data.id),
            items: data.items.map { OrderItem.fromPersistence($0) },
            status: status,
            createdAt: data.createdAt
        )
    }
}

extension Money {
    public static func fromCents(_ cents: Int, currency: Currency) -> Money {
        Money(amount: Decimal(cents) / 100, currency: currency)
    }

    public static func zero(_ currency: Currency) -> Money {
        Money(amount: 0, currency: currency)
    }
}
```
