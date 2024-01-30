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