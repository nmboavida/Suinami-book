Associated readings:
- [Sui Move by Example: Witness](https://examples.sui.io/patterns/witness.html)
- [OriginByte: Delegated Witness](https://github.com/Origin-Byte/nft-protocol/blob/main/contracts/permissions/sources/permissions/witness.move)

# Delegated Witness

> The witness pattern is a fundamental pattern in Sui Move for building a permissioning system around the types of your smart contract. A certain contract might declare an `Object<T>` which uses the witness pattern to allow for the contract that creates `T` to maintain exclusivity when generating `Object<T>`.

Let's say that in contract A declares the following type and constructor:

```rust
module examples::contract_a {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;

    struct ObjectA<phantom T: drop> has key, store {
        id: UID
    }

    public fun new<T: drop>(
        _witness: T, ctx: &mut TxContext
    ): ObjectA<T> {
        ObjectA { id: object::new(ctx) }
    }
}
```

Contract X can then declare a Witness type such that:

```rust
module examples::contract_x {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    use examples::contract_a;

    // Witness type
    struct TypeX has drop {}

    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(
            contract_a::new(TypeX {}, ctx),
            tx_context::sender(ctx)
        )
    }
}
```

Given that only `contract_b` can instantiate `TypeB`, we guarante that `Object<TypeB>` can only be created by `contract_b` even though the generic object `Object` is declared in `contract_a`.

## Using the `Witness` pattern for multiple types

The example above shows the power of the `Witness` pattern. However, this type of permissioning works when `T` has `drop`. What if we have a case in which `SomeObject<T: key + store>`? In this case, we can use a slightly different version of the witness pattern:

```rust
module examples::contract_b {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use ob_utils::utils;

    struct ObjectB<T: key + store> has key, store {
        id: UID,
        obj: T
    }

    public fun new<W: drop, T: key + store>(
        _witness: W, obj: T, ctx: &mut TxContext
    ): ObjectB<T> {
        // Asserts that `W` and `T` come from the same
        // module, via type reflection
        utils::assert_same_module<W, T>();

        ObjectB { id: object::new(ctx), obj }
    }
}
```

Now this allow us to use the our witness object to insert any object from our module with `key` and `store` in `Object<T>`:

```rust
module examples::contract_y {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};

    use examples::contract_b;

    // Witness type
    struct Witness has drop {}

    struct TypeY has key, store {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        transfer::public_transfer(
            contract_b::new(Witness {}, TypeY { id: object::new(ctx) }, ctx),
            tx_context::sender(ctx)
        )
    }
}
```

Note that this pattern functions well for objects that wrap other objects with `key` and `store`. Under the hood we are using an assertion exported by the OriginByte utils module implemented as follows:

```rust
/// Assert that two types are exported by the same module.
public fun assert_same_module<T1, T2>() {
    let (package_a, module_a, _) = get_package_module_type<T1>();
    let (package_b, module_b, _) = get_package_module_type<T2>();

    assert!(package_a == package_b, EInvalidWitnessPackage);
    assert!(module_a == module_b, EInvalidWitnessModule);
}

public fun get_package_module_type<T>(): (String, String, String) {
    let t = string::utf8(ascii::into_bytes(
        type_name::into_string(type_name::get<T>())
    ));

    get_package_module_type_raw(t)
}

public fun get_package_module_type_raw(t: String): (String, String, String) {
    let delimiter = string::utf8(b"::");

    // TBD: this can probably be hard-coded as all hex addrs are 64 bytes
    let package_delimiter_index = string::index_of(&t, &delimiter);
    let package_addr = sub_string(&t, 0, string::index_of(&t, &delimiter));

    let tail = sub_string(&t, package_delimiter_index + 2, string::length(&t));

    let module_delimiter_index = string::index_of(&tail, &delimiter);
    let module_name = sub_string(&tail, 0, module_delimiter_index);

    let type_name = sub_string(&tail, module_delimiter_index + 2, string::length(&tail));

    (package_addr, module_name, type_name)
}
```

## Delegated Witness

The delegated witness functions as an hybrid between the `Witness` and the `Publisher` pattern with the addition that it provides a `WitnessGenerator` which allows for the witness creation to be delegated to other smart contracts/objects defined in modules other than the creator of `T`.

In a nutshell, the differences between a Delegated-Witness and a typical Witness are:
- Deletaged-Witness has copy and it can therefore be easily propagated accross a stack of function calls;
- Deletaged-Witness is typed, and this in conjunction with the copy ability allows for the reduction of type-reflected assertions that are required to be perfomed accross the call stack
- A Delegated-Witness can be created by `Witness {}`, so like the witness its access can be designed by the smart contract that defines `T`;
- It can also be created directly through the Publisher object;
- It can be generated by a generator object `WitnessGenerator<T>` which has store ability, therefore allowing for witness-creation process to be more flexibly delegated.

Note: This pattern enhaces the programability around object permissions but it should be handled with care, and developers ought to fully understand its safety implications. In addition, one can use this pattern without the `WitnessGenerator<T>`, rather this generator is in of itself a pattern that is built on top of the Delegated Witness.

From the OriginByte permissions package we have:

```rust
/// Delegated witness of a generic type. The type `T` can either be
/// the One-Time Witness of a collection or the type of an object itself.
struct Witness<phantom T> has copy, drop {}

/// Delegate a delegated witness from arbitrary witness type
public fun from_witness<T, W: drop>(_witness: W): Witness<T> {
    utils::assert_same_module_as_witness<T, W>();
    Witness {}
}

/// Creates a delegated witness from a package publisher.
/// Useful for contracts which don't support our protocol the easy way,
/// but use the standard of publisher.
public fun from_publisher<T>(publisher: &Publisher): Witness<T> {
    utils::assert_publisher<T>(publisher);
    Witness {}
}
```

We can now have two contract that do:

```rust
module examples::contract_c {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use ob_permissions::witness::{Witness as DelegatedWit};

    struct ObjectC<T: key + store> has key, store {
        id: UID,
        obj: T
    }

    public fun new<T: key + store>(
        _delegated_wit: DelegatedWit<T>, obj: T, ctx: &mut TxContext
    ): ObjectC<T> {
        ObjectC { id: object::new(ctx), obj }
    }
}

module examples::contract_d {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use ob_permissions::witness::{Witness as DelegatedWit};

    use examples::contract_c::{Self, ObjectC};

    struct ObjectD<T: key + store> has key, store {
        id: UID,
        obj_c: ObjectC<T>
    }

    public fun new<T: key + store>(
        delegated_wit: DelegatedWit<T>, obj_c: T, ctx: &mut TxContext
    ): ObjectD<T> {
        ObjectD {
            id: object::new(ctx),
            obj_c: contract_c::new(delegated_wit, obj_c, ctx)
        }
    }
}
```

In other words the authorization can be propagated throughout the call stack.

## Witness Generator
TODO!