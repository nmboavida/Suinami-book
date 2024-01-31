Associated readings:
- [Sui Docs: Dynamic Fields](https://docs.sui.io/concepts/dynamic-fields)
- [Examples: Transferable DFs](https://github.com/nmboavida/suinami-book/blob/main/examples/sources/transferable_dfs.move)

# Transferable Dynamic-Fields

>In the Sui blockchain, dynamic fields are a flexible feature allowing users to add, modify, or remove fields from blockchain objects on-the-fly.
>
>These fields can be named arbitrarily and can store heterogeneous values, offering more versatility compared to fixed fields defined at the time of module publication. There are two types: 'fields' that can store any value but make wrapped objects inaccessible by external tools, and 'object fields' that must store objects but remain accessible by their ID.

One challenge that dynamic fields introduce is that when we attach dynamic fields to an object UID, if for any reason we want to burn the underlying object and move the dynamic fields to another object, we would have to perform `2n` amount of `remove` and `add` operations, where `n` is the number of dynamic fields.

This becomes especially hard if the dynamic fields are protected with key objects from a myriad of different packages. In words it pretty much becomes impossible to move the fields in a single programmable transaction and puts a big strain on the client side to build such transactions as the client would have to know upfront all the packages it needs to interact with.

To fix for this challenge, we introduce transferable dynamic fields by allocating the dynamic fields not to the field `id: UID` of the object but to a special field of its own:

```rust
module examples::transferable_dfs {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    struct MyObject {
        id: UID,

        // .. other fields

        /// We use this UID instead to store the dynamic fields
        dfs: UID
    }

    // ...
}
```

In Sui Move, we cannot transfer the `id: UID` to another object, as this is forbidden. Nonetheless, we can transfer `UID` that are not themselves the `id` field of the object. We can therefore have a `burn` function that looks like this:

```rust
module examples::transferable_dfs {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    // ..

    // This function is just for illustration. In a real-world scenario
    // it would most likely have permissions around it.
    public fun burn(
        obj: MyObject,
    ): UID {
        let MyObject { id, dfs } = obj;

        object::delete(id);

        dfs
    }
}
```

We would then be able to move the dynamic fields to the new object.
