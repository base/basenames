[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@ensdomains/buffer/=lib/buffer", 
    "solady/=lib/solady/src/",
    "forge-std/=lib/forge-std/src/",
    "ens-contracts/=lib/ens-contracts/contracts/",
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
    "openzeppelin-contracts/=lib/openzeppelin-contracts",
    "eas-contracts/=lib/eas-contracts/contracts/",
    "verifications/=lib/verifications/src",
    "openzeppelin-contracts-upgradeable/=lib/openzeppelin-contracts-upgradeable/contracts/"
]
fs_permissions = [{access = "read", path = "./script/premint/"}]
auto_detect_remappings = false

[rpc_endpoints]
sepolia="${SEPOLIA_RPC_URL}"
base-sepolia="${BASE_SEPOLIA_RPC_URL}"

[etherscan]
sepolia={url = "https://api-sepolia.etherscan.io/api", key = "${ETHERSCAN_API_KEY}"}
base-sepolia={url = "https://api-sepolia.basescan.org/api", key = "${BASE_ETHERSCAN_API_KEY}"}
