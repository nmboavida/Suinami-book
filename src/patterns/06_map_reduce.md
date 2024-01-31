- [Suinamic Book: Transferable DFs](05_transferable_dfs.md)
- [Examples: Map-Reduce](https://github.com/nmboavida/suinami-book/blob/main/examples/sources/map_reduce.move)

# Map-Reduce

Map Reduce is a pattern inspired in a Big Data pattern initially developed by the Hadoop framework and is a programming model that processes large data sets by dividing the work into two phases: the Map phase, which applies operations on individual or chunks of data, and the Reduce phase, which performs a final aggregation operation.

But how does this relate to Sui?

In Sui, operations on Single Writer Objects are fully parallelizable whereas operations on Shared Objects need to go through full consensus. With the Sui Map-Reduce pattern we can levage SWO transactions to add tens if not hundreds of thousands of objects to a Shared Object whilst having most transactions being parallelized. We do this by leveraging the Transferable Dynamic Fields pattern discussed previously.

Lets start with an example of two objects that represent the same abstraction, though one is private and the other one is shared:

```rust
module examples::map_reduce {
    use std::vector;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::dynamic_object_field as dof;

    /// `PrivateWarehouse` object which stores Digital Assets
    struct PrivateWarehouse<phantom T> has key, store {
        /// `Warehouse` ID
        id: UID,
        total_deposited: u64,
        warehouse: UID,
    }

    /// `SharedWarehouse` object which stores Digital Assets
    struct SharedWarehouse<phantom T> has key, store {
        /// `Warehouse` ID
        id: UID,
        total_deposited: u64,
        warehouse: vector<UID>,
    }

    /// Creates a `PrivateWarehouse` and transfers to transaction sender
    public entry fun new_private<T: key + store>(
        ctx: &mut TxContext
    ) {
        let warehouse = PrivateWarehouse<T> {
            id: object::new(ctx),
            total_deposited: 0,
            warehouse: object::new(ctx),
        };

        transfer::transfer(warehouse, tx_context::sender(ctx));
    }

    /// Adds NFTs to `PrivateWarehouse` in bulk
    public entry fun add_nfts<T: key + store>(
        warehouse: &mut PrivateWarehouse<T>,
        nfts: vector<T>,
    ) {
        let len = vector::length(&nfts);
        let i = 0;

        while (len > 0) {
            let nft = vector::pop_back(&mut nfts);
            dof::add(&mut warehouse.warehouse, i, nft);

            len = len - 1;
            i = i + 1;
        };

        vector::destroy_empty(nfts);
    }

    /// Burns `PrivateWarehouse`s in builk, moves NFTs to `SharedWarehouse`
    public fun share_warehouse<T: key + store>(
        warehouses: vector<PrivateWarehouse<T>>,
        ctx: &mut TxContext
    ) {
        let shared_warehouse = SharedWarehouse<T> {
            id: object::new(ctx),
            total_deposited: 0,
            warehouse: vector::empty(),
        };

        let len = vector::length(&warehouses);
        let i = 0;

        while (len > 0) {
            let wh = vector::pop_back(&mut warehouses);
            let PrivateWarehouse { id, total_deposited: new_deposit, warehouse: wh_ } = wh;

            object::delete(id);
            shared_warehouse.total_deposited = shared_warehouse.total_deposited + new_deposit;
            vector::push_back(&mut shared_warehouse.warehouse, wh_);

            len = len - 1;
            i = i + 1;
        };

        vector::destroy_empty(warehouses);
        transfer::share_object(shared_warehouse);
    }
}
```

We can now instantiate SWO warehouses in parallel calling `new_private`, add any non-fungible asset in parallel by calling `add_nfts`. This is the "Map" part in the "Map-Reduce". We then call `share_warehouse` which will burn all individual private warehouses, and aggregate all its NFTs into a shared warehouse.
