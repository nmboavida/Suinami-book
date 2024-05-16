module examples::dangling_coin {
    use sui::coin;
    use sui::sui::SUI;
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::test_scenario::{Self, ctx};

    const SOME_ADDRESS: address = @0x1;

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