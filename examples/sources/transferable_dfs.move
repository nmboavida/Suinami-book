// TODO: Add example tests
module examples::transferable_dfs {
    use sui::tx_context::TxContext;
    use sui::object::{Self, UID};

    struct MyObject {
        id: UID,

        // .. other fields

        /// We use this UID instead to store the dynamic fields
        dfs: UID
    }

    // This function is just for illustration. In a real-world scenario
    // it would most likely have permissions around it.
    public fun new(
        ctx: &mut TxContext,
    ): MyObject {

        let my_obj = MyObject {
            id: object::new(ctx),
            dfs: object::new(ctx),
        };

        my_obj
    }
    
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