Associated readings:
- [Sui Move by Example: Hot Potato](https://examples.sui.io/patterns/hot-potato.html)
- [Move by Example: Publisher](https://examples.sui.io/basics/publisher.html)
- [OriginByte: Frozen Publisher](https://github.com/Origin-Byte/nft-protocol/blob/main/contracts/permissions/sources/permissions/frozen_publisher.move)

# Frozen Publisher

> The Publisher Object in Sui confers authority to the publisher, in other words, to the one deploying the contract on-chain. With it developers can create priviledged entrypoints of which only the holder of the `Publisher` object can call. The `Publisher` along with its `package` module is essentially used to verify if a type `T` is part of a module or package associated with the `Publisher` object.

The `Publisher` pattern is a powerful permissioning pattern in Sui Move, and its use case can be seen in the Sui Display standard.

> The Sui Object Display standard functions as a template engine, facilitating the management of how an object is represented off-chain through on-chain mechanisms. This standard allows for the integration of an object's data into a template string, offering flexibility in the selection of fields to include.

One challenge that arises with it however is when using wrapper types `Wrapper<T>`, in that it not possible for a type `T` to define its own display if its wrapped by `Wrapper<T>`. The is because the outer type take precedence over the inner type.

We introduce the idea of a `FrozenPublisher` which can be used by the wrapper module to allow for the publisher of `T` to define its own display of `Wrapper<T>`. In other words it allows the publisher of the type `Wrapper` to delegate to the type `T`. This way, the inner type `T` has the necessary degrees of freedom to define its display.

```rust
module ob_permissions::frozen_publisher {
    // ...

    struct FrozenPublisher has key {
        id: UID,
        inner: Publisher,
    }

    // ...

    public fun freeze_from_otw<OTW: drop>(otw: OTW, ctx: &mut TxContext) {
        public_freeze_object(new(package::claim(otw, ctx), ctx));
    }

    // ...
}
```

Say that want to create a wrapper type `Wrapper<T>` which allows other types to instantiate it:

```rust
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
}
```

We can then add a function that lets the inner type witnesses export their inner display:

```rust
module examples::export_display {
    // ...

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
```

We can then create a `FrozenPublisher` and freeze it:

```rust
module examples::export_display {
    fun init(otw: TEST_WRAPPED_DISPLAY, ctx: &mut TxContext) {
        // ...

        frozen_publisher::freeze_from_otw(otw, ctx(&mut scenario));

        // ...
    }
}
```

This allows others developers that come along and create their inner types `T` and create their display for `Wrapper<T>` as shown in the test code below:

```rust
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
```



