- [Examples: On-Chain Events](https://github.com/nmboavida/suinami-book/blob/main/examples/sources/onchain_events.move)


# On-chain Events

With Sui's on-chain storage economics, it is economically feasible to record events on-chain. We could therefore expose an inner API for our program events, to the programs themselves:


```rust
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
```

