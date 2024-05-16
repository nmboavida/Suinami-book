module examples::events {
    use sui::event;
    use sui::test_scenario;

    const SOME_ADDRESS: address = @0x1;

    struct Event<T: copy + drop> has copy, drop {
        event: T,
    }

    struct SomeEvent has copy, drop {}

    fun emit_event() {
        event::emit(Event { event: SomeEvent {}});
    }

    #[test]
    fun emit_event_test() {
        let scenario = test_scenario::begin(SOME_ADDRESS);

        emit_event();

        test_scenario::end(scenario);
    }

}