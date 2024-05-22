Associated readings:
- [Sui Docs: Dynamic Fields](https://docs.sui.io/concepts/dynamic-fields)
- [OriginByte: Dynamic Vector](https://github.com/Origin-Byte/nft-protocol/blob/main/contracts/utils/sources/dynamic_vec.move)

# Dangling Coins

In the Sui blockchain, an object with dynamic fields can be deleted, even if those fields are not deleted with it. Once the object is deleted, all its dynamic fields become unreachable for future transactions, in other words they become dangling objects. This is the case no matter if these field values are equipped with the 'drop' ability or not.


This is especially problematic if the object concerned has some real-world value such as `Coin<T>`. take the following example:

```rust
module examples::dangling_coin {
    use sui::coin;
    use sui::sui::SUI;
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::test_scenario::{Self, ctx};

    const SOME_ADDRESS: address = @0x1;
    const USER: address = @0x2;

    struct SomeObject has key, store {
        id: UID,
    }

    fun burn_obj(obj: SomeObject) {
        let SomeObject { id } = obj;
        object::delete(id);
    }

    #[test]
    fun dangling_coin() {
        let scenario = test_scenario::begin(SOME_ADDRESS);
        let some_obj = SomeObject {
            id: object::new(ctx(&mut scenario)),
        };

        let sui_coins = coin::mint_for_testing<SUI>(10_000, ctx(&mut scenario));

        df::add(&mut some_obj.id, 1, sui_coins);

        burn_obj(some_obj);

        test_scenario::end(scenario);
    }

}
```

This code does in fact compile and the test passes. In other words, in this test case, 10_000 SUI coins have become unreachable. We recommend developers to always be extra cautious when burning object that have dynamic fields such that validations are put in place to prevent them from being burned in case valueable assets are held dynamically in it.