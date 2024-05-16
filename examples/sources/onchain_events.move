module examples::onchain_events {
    use sui::tx_context::TxContext;
    use sui::event;
    use sui::transfer;
    use sui::table_vec::{Self, TableVec};
    use sui::dynamic_field as df;
    use sui::object::{Self, UID};
    use sui::test_scenario::{Self, ctx};

    const SOME_ADDRESS: address = @0x1;

    struct EventLogs has key, store {
        id: UID,
    }

    struct EventAKey has copy, store, drop {}
    struct EventBKey has copy, store, drop {}

    struct EventA has copy, store, drop {}
    struct EventB has copy, store, drop {}

    fun emit_event_a(
        logs: &mut EventLogs,
    ) {
        let event = EventA {};
        append_event(logs, EventAKey {}, event);
        event::emit(event);
    }
    
    fun emit_event_b(
        logs: &mut EventLogs,
    ) {
        let event = EventB {};
        append_event(logs, EventBKey {}, event);
        event::emit(event);
    }

    fun append_event<EK: copy + store + drop, E: copy + store + drop>(
        logs: &mut EventLogs,
        key: EK,
        event: E
    ) {
        let logs: &mut TableVec<E> = df::borrow_mut(&mut logs.id, key);
        table_vec::push_back(logs, event);
    }
    
    fun init_event<EK: copy + store + drop, E: copy + store + drop>(
        logs: &mut EventLogs,
        key: EK,
        ctx: &mut TxContext,
    ) {
        df::add(&mut logs.id, key, table_vec::empty<E>(ctx));
    }

    #[test]
    fun onchain_events_test() {
        let scenario = test_scenario::begin(SOME_ADDRESS);
        let logs = EventLogs {
            id: object::new(ctx(&mut scenario)),
        };

        init_event<EventAKey, EventA>(&mut logs, EventAKey {}, ctx(&mut scenario));
        init_event<EventBKey, EventB>(&mut logs, EventBKey {}, ctx(&mut scenario));


        emit_event_a(&mut logs);
        emit_event_b(&mut logs);

        transfer::public_share_object(logs);

        test_scenario::end(scenario);
    }

}