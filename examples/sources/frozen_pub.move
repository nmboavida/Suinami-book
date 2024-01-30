module examples::export_display {
    use std::string;
    use sui::display::{Self, Display};
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use ob_permissions::frozen_publisher::{Self, FrozenPublisher};
    use ob_permissions::witness::{Witness as DelegatedWitness};

    struct Witness has drop {}

    struct Wrapper<T: key + store> has key, store {
        id: UID,
        inner: T
    }

    public fun new<T: key + store>(inner: T, ctx: &mut TxContext): Wrapper<T> {
        Wrapper { id: object::new(ctx), inner }
    }

    // === Display standard ===

    /// Creates a new `Display` with some default settings.
    public fun new_display<T: key + store>(
        _witness: DelegatedWitness<T>,
        pub: &FrozenPublisher,
        ctx: &mut TxContext,
    ): Display<Wrapper<T>> {
        let display =
            frozen_publisher::new_display<Witness, Wrapper<T>>(Witness {}, pub, ctx);

        display::add(&mut display, string::utf8(b"type"), string::utf8(b"Wrapper"));

        display
    }
}

#[test_only]
module examples::test_wrapped_display {
    use std::string::utf8;
    use sui::object::UID;
    use sui::transfer;
    use sui::display;
    use sui::test_scenario::{Self, ctx};
    use ob_permissions::frozen_publisher::{Self, FrozenPublisher};
    use ob_permissions::witness;

    use examples::export_display;

    // One Time Witness
    struct TEST_WRAPPED_DISPLAY has drop {}

    // Witness for authentication
    struct Witness has drop {}

    struct InnerType has key, store {
        id: UID,
    }

    const WRAPPER_PUBLISHER_ADDR: address = @0x1;
    const INNER_PUBLISHER_ADDR: address = @0x2;

    #[test]
    fun create_wrapped_display() {
        let scenario = test_scenario::begin(WRAPPER_PUBLISHER_ADDR);

        frozen_publisher::freeze_from_otw(TEST_WRAPPED_DISPLAY {}, ctx(&mut scenario));

        test_scenario::next_tx(&mut scenario, INNER_PUBLISHER_ADDR);

        let dw = witness::from_witness<InnerType, Witness>(Witness {});
        
        let frozen_pub = test_scenario::take_immutable<FrozenPublisher>(&scenario);

        let inner_display = export_display::new_display(dw, &frozen_pub, ctx(&mut scenario));

        display::add(&mut inner_display, utf8(b"name"), utf8(b"InnerType"));
        display::add(&mut inner_display, utf8(b"description"), utf8(b"This is the inner display for Wrapper<InnerType>"));

        transfer::public_transfer(inner_display, INNER_PUBLISHER_ADDR);

        test_scenario::return_immutable(frozen_pub);
        test_scenario::end(scenario);
    }
}
