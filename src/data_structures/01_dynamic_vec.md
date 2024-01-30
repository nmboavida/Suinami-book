Associated readings:
- [Sui Docs: Dynamic Fields](https://docs.sui.io/concepts/dynamic-fields)
- [OriginByte Utils: Dynamic Vector](https://github.com/Origin-Byte/nft-protocol/blob/main/contracts/utils/sources/dynamic_vec.move)

# Dynamic Vectors

In the Sui blockchain, dynamic fields are a flexible feature allowing users to add, modify, or remove fields from blockchain objects on-the-fly.

These fields can be named arbitrarily and can store heterogeneous values, offering more versatility compared to fixed fields defined at the time of module publication. There are two types: 'fields' that can store any value but make wrapped objects inaccessible by external tools, and 'object fields' that must store objects but remain accessible by their ID.

Dynamic fields are great because they serve as an abstraction for unbounded object scalability and extendibility. An example of scalability is the object type `TableVec` which allows us to create an arbitrarily long vector.

```rust
struct TableVec<phantom Element: store> has store {
    /// The contents of the table vector.
    contents: Table<u64, Element>,
}
```

## Runtime hit

One trade-off when using dynamic fields to scale your objects in size is that your application will suffer a runtime hit. This is fine for most cases, but for perfomance critical applications you can use a dynamic vector from the OriginByte library:

```rust
struct DynVec<Element> has store {
    vec_0: vector<Element>,
    vecs: UID,
    current_chunk: u64,
    tip_length: u64,
    total_length: u64,
    limit: u64,
}
```

This abstraction combines the best of both worlds, the runtime performance of static fields, and the scalability of dynamic fields. In a nutshell, `DynVec` loads the tip of the entire vector into a static field vector, allowing `push_back` and `pop_back` operations to be more perfomant. When popping an element from the vector, when the the sub-vector tip gets exhausted we load the next chunk to the static vector.

```rust
public fun pop_back<Element: store>(
    v: &mut DynVec<Element>,
): Element {
    // This only occurs when it has no elements
    assert!(v.tip_length != 0, 0);

    let elem = if (v.tip_length == 1) {
        remove_chunk(v)
    } else {
        pop_element_from_chunk(v)
    };

    elem
}
```

Conversely, when we push elements to the back of the vector, when the sub-vector tip gets full, we move it to a dynamic field and instantiate a new static vector.

```rust
public fun push_back<Element: store>(
    v: &mut DynVec<Element>,
    elem: Element,
) {
    // If the tip is maxed out, create a new vector and add it there
    if (v.tip_length == v.limit) {
        insert_chunk(v, elem);
    } else {
        push_element_to_chunk(v, elem);
    };
}
```


To create a dynamic vector you can simply call the `empty` constructor function and passing a limit which defines the capacity of each vector chunk.

```rust
/// Create an empty dynamic vector.
public fun empty<Element: store>(limit: u64, ctx: &mut TxContext): DynVec<Element> {
    DynVec {
        vec_0: vector::empty(),
        vecs: object::new(ctx),
        current_chunk: 0,
        tip_length: 0,
        total_length: 0,
        limit,
    }
}
```