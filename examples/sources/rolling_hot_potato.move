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

#[test_only]
module examples::test_rolling_hot_potato {
    use sui::transfer;
    use sui::test_scenario::{Self, ctx};
    use ob_request::request::Policy;

    use examples::request_policy::{Self, AUTH_REQ};
    use examples::policy_actions::{Self, RuleA, RuleB, RuleC};

    const POLICY_ADMIN: address = @0x1;
    const USER: address = @0x2;

    #[test]
    fun test_rolling_hp() {
        let scenario = test_scenario::begin(POLICY_ADMIN);

        let (policy, cap) = request_policy::init_policy(ctx(&mut scenario));

        
        // Admin enforces rules A, B and C
        request_policy::enforce<RuleA>(&mut policy, &cap);
        request_policy::enforce<RuleB>(&mut policy, &cap);
        request_policy::enforce<RuleC>(&mut policy, &cap);
        
        // PolicyCap is sent to admin address
        transfer::public_transfer(cap, POLICY_ADMIN);
        // Policy is made shared
        transfer::public_share_object(policy);

        // Test abiding USER that performs all required actions
        test_scenario::next_tx(&mut scenario, USER);

        let policy = test_scenario::take_shared<Policy<AUTH_REQ>>(&scenario);

        let request = policy_actions::genesis_action(&policy, ctx(&mut scenario)); // Genesis action gives rise to request hot potato
        
        // User performs all required actions
        policy_actions::action_a(&mut request);
        policy_actions::action_b(&mut request);
        policy_actions::action_c(&mut request);

        // The request hot potato can now be safely destroyed
        request_policy::confirm(request, &policy);

        test_scenario::return_shared(policy);
        test_scenario::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = ob_request::request::EPolicyNotSatisfied)]
    fun test_fail_rolling_hp() {
        let scenario = test_scenario::begin(POLICY_ADMIN);

        let (policy, cap) = request_policy::init_policy(ctx(&mut scenario));

        
        // Admin enforces rules A, B and C
        request_policy::enforce<RuleA>(&mut policy, &cap);
        request_policy::enforce<RuleB>(&mut policy, &cap);
        request_policy::enforce<RuleC>(&mut policy, &cap);
        
        // PolicyCap is sent to admin address
        transfer::public_transfer(cap, POLICY_ADMIN);
        // Policy is made shared
        transfer::public_share_object(policy);

        // Test abiding USER that performs all required actions
        test_scenario::next_tx(&mut scenario, USER);

        let policy = test_scenario::take_shared<Policy<AUTH_REQ>>(&scenario);

        let request = policy_actions::genesis_action(&policy, ctx(&mut scenario)); // Genesis action gives rise to request hot potato
        
        // User performs all required actions
        policy_actions::action_a(&mut request);

        // The request hot potato can now be safely destroyed
        request_policy::confirm(request, &policy);

        test_scenario::return_shared(policy);
        test_scenario::end(scenario);
    }
}
