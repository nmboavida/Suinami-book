Associated readings:
- [Sui Docs: Programmable Transactions](https://docs.sui.io/concepts/transactions/prog-txn-blocks)
- [Sui Move by Example: Hot Potato](https://examples.sui.io/patterns/hot-potato.html)
- [Examples: Hot Potato Wrapper](https://github.com/nmboavida/suinami-book/blob/main/examples/sources/hot_potato_wrapper.move)

# Hot Potato Wrapper

In Sui, a hot potato is an object without abilities, and that therefore must be consumed in the same transactional batch that is has been created in (since it does not have `drop` ability it must be burned by the contract that declared its type). This is a very useful pattern because it allows developers to enforce that a certain chain of programmable calls ought to be executed, otherwise leading to the transaction batch failing. This pattern became extremely powerful especially since the introduction of Programmable Transactions.

Hot Potatoes are composable, which means that you can wrap them in other Hot Potatoes:

```rust

module examples::hot_potato_wrapper {
    use sui::test_scenario;

    struct HotPotato {}

    struct HotPotatoWrapper {
        potato: HotPotato
    }

    fun delete_potato_wrapper(wrapper: HotPotatoWrapper): HotPotato {
        let HotPotatoWrapper {
            potato,
        } = wrapper;

        potato
    }

    fun delete_potato(potato: HotPotato) {
        let HotPotato {} = potato;
    }

    #[test]
    fun try_wrap_potato() {
        let scenario = test_scenario::begin(@0x0);

        let potato_wrapper = HotPotatoWrapper {
            potato: HotPotato {},
        };

        let potato = delete_potato_wrapper(potato_wrapper);

        delete_potato(potato);

        test_scenario::end(scenario);
    }
}
```