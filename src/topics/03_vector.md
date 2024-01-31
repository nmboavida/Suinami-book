# vector[] syntax

Vectors are a pretty standard structure in Move. To initiate a vector you would normally write:

```rust
let my_vec = vector::empty();
vector::append(&mut my_vec, 1);
vector::append(&mut my_vec, 2);
vector::append(&mut my_vec, 3);
```

To make it more ergonomic, you can use the `vector[]` syntax as follows:
```rust
let my_vec = vector[1, 2, 3];
```
