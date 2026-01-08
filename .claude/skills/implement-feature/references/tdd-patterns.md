# TDD Test Patterns (Chicago School)

We follow **Chicago school TDD** (state-based testing):

| Chicago School (We Use This)          | London School (Avoid)                    |
|---------------------------------------|------------------------------------------|
| Test state changes and return values  | Test interactions between objects        |
| Mocks stub data, not verify calls     | Mocks verify method calls were made      |
| Focus on "what" (outcomes)            | Focus on "how" (behavior)                |
| Design emerges from tests             | Design upfront, tests verify design      |
| Fewer, coarser-grained tests          | Many fine-grained interaction tests      |

## Swift Testing Framework

Use `@Test` and `@Suite` instead of XCTest:

```swift
import Testing
import Foundation
@testable import Domain

@Suite
struct OrderTests {
    @Test func `order at pending status can be cancelled`() {
        let order = Order(items: [], status: .pending)
        #expect(order.canBeCancelled == true)
    }
}
```

## Given-When-Then Structure

```swift
@Test func `order computes total from items`() {
    // Given
    let order = Order(items: [
        OrderItem(price: 10, quantity: 2),
        OrderItem(price: 5, quantity: 1)
    ], status: .pending)

    // When
    let total = order.totalAmount

    // Then
    #expect(total == 25)
}
```

## Mocking with @Mockable (Chicago Style)

Define mockable protocols for external dependencies:

```swift
import Mockable

@Mockable
public protocol OrderRepository: Sendable {
    func fetch(id: OrderId) async throws -> Order
    func save(_ order: Order) async throws
}

@Mockable
public protocol NetworkClient: Sendable {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
}
```

**Chicago school mock usage** - stub return values, verify resulting state:

```swift
import Mockable

@Suite
struct OrderServiceTests {
    @Test func `service returns order on fetch`() async throws {
        // Given - STUB dependencies to return data
        let mockRepo = MockOrderRepository()
        let expectedOrder = Order(
            id: OrderId("123"),
            items: [OrderItem(price: 10, quantity: 1)],
            status: .pending
        )
        given(mockRepo).fetch(id: any()).willReturn(expectedOrder)

        let service = OrderService(repository: mockRepo)

        // When
        let result = try await service.getOrder(id: "123")

        // Then - verify STATE, not that methods were called
        #expect(result.status == .pending)
        #expect(result.totalAmount == 10)
        // AVOID: verify(mockRepo).fetch(id: any()).called(1)  // London school - don't do this
    }
}
```

**Key principle**: Use `given().willReturn()` to stub data. Avoid `verify().called()` for interactions.

## Domain Model Tests

Test state and computed properties:

```swift
@Suite
struct MoneyTests {
    @Test func `money adds correctly with same currency`() {
        let money1 = Money(amount: 10, currency: .usd)
        let money2 = Money(amount: 5, currency: .usd)

        let result = money1.adding(money2)

        #expect(result.amount == 15)
        #expect(result.currency == .usd)
    }

    @Test func `money formats with currency symbol`() {
        let money = Money(amount: 99.99, currency: .usd)

        #expect(money.formatted == "$99.99")
    }
}

@Suite
struct OrderStatusTests {
    @Test func `pending status needs attention`() {
        #expect(OrderStatus.pending.needsAttention == true)
    }

    @Test func `delivered status is terminal`() {
        #expect(OrderStatus.delivered.isTerminal == true)
    }

    @Test func `shipped status does not need attention`() {
        #expect(OrderStatus.shipped.needsAttention == false)
    }
}
```

## Async Test Patterns

```swift
@Test func `repository returns order on success`() async throws {
    // Given
    let mockClient = MockNetworkClient()
    given(mockClient).request(any()).willReturn(
        OrderDTO(id: "123", status: "pending", items: [])
    )
    let repository = APIOrderRepository(client: mockClient)

    // When
    let order = try await repository.fetch(id: OrderId("123"))

    // Then
    #expect(order.id.value == "123")
    #expect(order.status == .pending)
}

@Test func `repository throws when network fails`() async {
    // Given
    let mockClient = MockNetworkClient()
    given(mockClient).request(any()).willThrow(NetworkError.connectionFailed)
    let repository = APIOrderRepository(client: mockClient)

    // When/Then
    await #expect(throws: RepositoryError.networkError) {
        try await repository.fetch(id: OrderId("123"))
    }
}
```

## Actor Tests

```swift
@Suite
struct OrderManagerTests {
    @Test func `manager caches fetched orders`() async throws {
        // Given
        let mockRepo = MockOrderRepository()
        let order = Order(id: OrderId("123"), items: [], status: .pending)
        given(mockRepo).fetch(id: any()).willReturn(order)

        let manager = OrderManager(repository: mockRepo)

        // When - fetch twice
        let first = try await manager.getOrder(OrderId("123"))
        let second = try await manager.getOrder(OrderId("123"))

        // Then - both return same order (cached)
        #expect(first.id == second.id)
    }

    @Test func `manager updates order status`() async throws {
        // Given
        let mockRepo = MockOrderRepository()
        var order = Order(id: OrderId("123"), items: [], status: .pending)
        given(mockRepo).fetch(id: any()).willReturn(order)
        given(mockRepo).save(any()).willReturn(())

        let manager = OrderManager(repository: mockRepo)

        // When
        try await manager.updateStatus(OrderId("123"), to: .processing)
        let updated = try await manager.getOrder(OrderId("123"))

        // Then - verify state changed
        #expect(updated.status == .processing)
    }
}
```

## Test Organization

```
Tests/
├── DomainTests/
│   ├── Models/
│   │   ├── OrderTests.swift        # Domain model behavior
│   │   ├── MoneyTests.swift        # Value object behavior
│   │   └── OrderStatusTests.swift  # Enum behavior
│   └── Services/
│       └── OrderManagerTests.swift # Actor behavior
└── InfrastructureTests/
    └── Repositories/
        ├── APIOrderRepositoryTests.swift  # Repository behavior
        └── OrderParsingTests.swift        # Parsing logic
```

## Running Tests

```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter DomainTests

# Run specific test
swift test --filter "OrderTests/order computes total from items"
```

## Chicago School Summary

### What to Test

| Test Type           | What to Assert                                    |
|---------------------|---------------------------------------------------|
| Domain models       | Computed properties, state after mutations        |
| Services/Repos      | Return values, thrown errors, resulting state     |
| Actors              | State after operations complete                   |

### What NOT to Test

- That a method was called N times
- The order of internal method calls
- Implementation details that don't affect observable state

### Red-Green-Refactor Cycle

```
1. RED    - Write a failing test that asserts expected STATE
2. GREEN  - Write minimal code to make the test pass
3. REFACTOR - Improve code while keeping tests green
```

Design emerges from this cycle - don't design upfront, let tests guide you.
