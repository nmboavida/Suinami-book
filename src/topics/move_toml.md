Associated readings:
- [Sui Docs: Packages](https://docs.sui.io/concepts/sui-move-concepts/packages)
- [Sui Move by Example: Move.toml](https://examples.sui.io/basics/move-toml.html)

# Deploying a contract

A couple of important things to keep in mind when deploying contracts.

To deploy a contract you need to keep its address as `0x`:

````toml
[package]
name = "Request"
version = "1.6.0"

[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
# mainnet-1.15.1
rev = "08119f95e9ccdc926eae3fff8c95e50678f56aed"

[dependencies.Permissions]
local = "./../permissions"

[addresses]
ob_request = "0x"
````

Once we have deployed the contract successfully we need to insert the package ID into the move.toml to link the codebase to the on-chain smart contract. When we deploy the contract a package ID will be generated, in our case is `0xe2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43`. We therefore add this as the address:

````toml
[package]
name = "Request"
version = "1.6.0"

[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
# mainnet-1.15.1
rev = "08119f95e9ccdc926eae3fff8c95e50678f56aed"

[dependencies.Permissions]
local = "./../permissions"

[addresses]
ob_request = "0xe2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43"
````

# Upgrading a contract

To upgrade the contract we have to reset the address to `0x` and invoke the call to upgrade the contract via the [sui-cli](https://docs.sui.io/references/cli). A new package will be generated. In our case the new version package is `0xadf32ebafc587cc86e1e56e59f7b17c7e8cbeb3315193be63c6f73157d4e88b9`. We now relink the codebase by adding the new package ID in the `published-at` field and add back the original package ID in the addresses:

```toml
[package]
name = "Request"
version = "1.6.0"
published-at = "0xadf32ebafc587cc86e1e56e59f7b17c7e8cbeb3315193be63c6f73157d4e88b9"

[dependencies.Sui]
git = "https://github.com/MystenLabs/sui.git"
subdir = "crates/sui-framework/packages/sui-framework"
# mainnet-1.15.1
rev = "08119f95e9ccdc926eae3fff8c95e50678f56aed"

[dependencies.Permissions]
local = "./../permissions"

[addresses]
ob_request = "0xe2c7a6843cb13d9549a9d2dc1c266b572ead0b4b9f090e7c3c46de2714102b43"
````
