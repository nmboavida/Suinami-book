Associated readings:
- [Sui Docs: Programmable Transactions](https://docs.sui.io/concepts/transactions/prog-txn-blocks)
- [Sui Move by Example: Hot Potato](https://examples.sui.io/patterns/hot-potato.html)
- [OriginByte: Request Hot Potato](https://github.com/Origin-Byte/nft-protocol/blob/main/contracts/request/sources/request/request.move)
- [Examples: Rolling Hot Potato](https://github.com/nmboavida/suinami-book/blob/main/examples/sources/rolling_hot_potato.move)

# Rolling Hot Potato

As stated in the previous chapter, in Sui, a hot potato is an object without abilities, and that therefore must be consumed in the same transactional batch that is has been created in (since it does not have drop ability it must be burned by the contract that declared its type). This is a very useful pattern because it allows developers to enforce that a certain chain of programmable calls ought to be executed, otherwise leading to the transaction batch failing. This pattern became extremely powerful especially since the introduction of Programmable Transactions.

Following the introduction of Programmable Transactions the Rolling Hot Potato pattern as been introduced by Mysten Labs and Originbyte in collaboration during the development of the Kiosk.

Below follows a generic implementation which seves as a way of validating that a set of actions has been taken. Since hot potatoes need to be consumed at the end of the Programmable Transactions Batch, smart contract developers can force clients to perform a particular set of actions given a genesis action.


The module can be found in OriginByte [Request](https://github.com/Origin-Byte/nft-protocol/tree/main/contracts/request) package and consists of three core objects:
- `Policy<P>` is the object that registers the rules enforced for the policy `P`, as well configuration state associated to each rule;
- `PolicyCap` is a capability object that gives managerial access for a given policy object
- `RequestBody<P>` is the inner body of a hot-potato object that contains the receipts collected by performing the enforced actions, as well as the metata associated to them as well as the policy resolution logic. `RequestBody<P>` is meant to be wrapped by a hot-potato object, but is itself a hot-potato.


Any developer can implement their logic on top of these generic objects in order to build their own chain of required actions. An example goes as follows:


```rust
module examples::request_policy {
    use sui::object::{Self, ID};
    use sui::tx_context::TxContext;
    use ob_request::request::{Self, RequestBody, Policy, PolicyCap};

    // === Errors ===

    const EPolicyMismatch: u64 = 1;

    // === Structs ===

    /// Witness for initating a policy
    struct AUTH_REQ has drop {}

    /// Rolling Hot Potato
    struct AuthRequest {
        policy_id: ID,

        // .. other fields ..

        inner: RequestBody<AUTH_REQ>
    }

    /// Construct a new `Request` hot potato which requires an
    /// approving action from the policy creator to be destroyed / resolved.
    public fun new(
        policy: &Policy<AUTH_REQ>, ctx: &mut TxContext,
    ): AuthRequest {
        AuthRequest {
            policy_id: object::id(policy),
            inner: request::new(ctx),
        }
    }

    public fun init_policy(ctx: &mut TxContext): (Policy<AUTH_REQ>, PolicyCap) {
        // Policy creation is gated using the Witness Pattern
        request::new_policy(AUTH_REQ {}, ctx)
    }

    /// Adds a `Receipt` to the `Request`, unblocking the request and
    /// confirming that the policy requirements are satisfied.
    public fun add_receipt<Rule: drop>(self: &mut AuthRequest, rule: Rule) {
        request::add_receipt(&mut self.inner, &rule);
    }

    // No need for witness protection as this is admin only endpoint,
    // protected by the `PolicyCap`. The type `Rule` is a type marker for
    // a given rule defined in an external contract
    public entry fun enforce<Rule: drop>(
        policy: &mut Policy<AUTH_REQ>, cap: &PolicyCap,
    ) {
        request::enforce_rule_no_state<AUTH_REQ, Rule>(policy, cap);
    }

    public fun confirm(self: AuthRequest, policy: &Policy<AUTH_REQ>) {
        let AuthRequest {
            policy_id,
            inner,
        } = self;
        assert!(policy_id == object::id(policy), EPolicyMismatch);
        request::confirm(inner, policy);
    }
}
```

We can now build a pipeline of required actions such that:

```rust
// ...

// User performs all required actions
policy_actions::action_a(&mut request);
policy_actions::action_b(&mut request);
policy_actions::action_c(&mut request);

// The request hot potato can now be safely destroyed
request_policy::confirm(request, &policy);
```

In other words, if the caller does not perform action A, B and C, the transaction will fail.

In order for these three actions to be required by the policy, their respective contracts need to export a function which has to be called by the owner of the policy:

```rust
// ...

// Admin enforces rules A, B and C
request_policy::enforce<RuleA>(&mut policy, &cap);
request_policy::enforce<RuleB>(&mut policy, &cap);
request_policy::enforce<RuleC>(&mut policy, &cap);
```

Actions can then be added from other contracts or modules:

```rust
module examples::policy_actions {
    use sui::tx_context::TxContext;
    use ob_request::request::Policy;

    use examples::request_policy::{Self, AuthRequest, AUTH_REQ};

    struct RuleA has drop {} // Witness and Type marker for Rule A
    struct RuleB has drop {} // Witness and Type marker for Rule B
    struct RuleC has drop {} // Witness and Type marker for Rule C

    public fun genesis_action(
        policy: &Policy<AUTH_REQ>, ctx: &mut TxContext,
    ): AuthRequest {
        request_policy::new(policy, ctx)
    }

    /// Performs a given action A
    public fun action_a(
        req: &mut AuthRequest,
    ) {
        // .. Performe some action ..

        request_policy::add_receipt(req, RuleA {})
    }
    
    /// Performs a given action B
    public fun action_b(
        req: &mut AuthRequest,
    ) {
        // .. Performe some action ..

        request_policy::add_receipt(req, RuleB {})
    }
    
    /// Performs a given action C
    public fun action_c(
        req: &mut AuthRequest,
    ) {
        // .. Performe some action ..

        request_policy::add_receipt(req, RuleC {})
    }
}
```