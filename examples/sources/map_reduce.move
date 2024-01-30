// TODO: Add example tests
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