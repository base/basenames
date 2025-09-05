#!/usr/bin/env python3
"""
Basename ENS Namehash Converter

This script reads basename handles from a CSV file and converts each handle 
to its corresponding ENS namehash. Each handle gets '.base.eth' appended 
before calculating the namehash (e.g., 'john' becomes 'john.base.eth').

Includes optional validation against the Base Registry contract to identify
unregistered names (those with zero address owners).

Configuration is loaded from environment variables via a .env file:
    - BASE_RPC_URL: Base network RPC endpoint  
    - REGISTRY_CONTRACT_ADDRESS: Base Registry contract address

Usage:
    python ens_namehash_converter.py [input_csv] [output_csv] [--no-validation]

If no arguments provided, defaults to:
    - Input: Basenames.csv
    - Output: namehashes_output.csv
    - Validation: ENABLED (use --no-validation to disable)
"""

import csv
import sys
import os
import json
from typing import List, Tuple, Optional
from Crypto.Hash import keccak
from web3 import Web3
from dotenv import load_dotenv

# Load environment variables from .env file
# Look for .env in project root (one level up from this script)
script_dir = os.path.dirname(__file__)
project_root = os.path.dirname(script_dir)
dotenv_path = os.path.join(project_root, '.env')
load_dotenv(dotenv_path)

# Load configuration from environment variables
BASE_RPC_URL = os.getenv('BASE_RPC_URL')
REGISTRY_CONTRACT_ADDRESS = os.getenv('REGISTRY_ADDR')

# Validate required environment variables
if not BASE_RPC_URL:
    print("Error: BASE_RPC_URL environment variable not found.")
    print("Please create a .env file with BASE_RPC_URL=<your_rpc_url>")
    sys.exit(1)

if not REGISTRY_CONTRACT_ADDRESS:
    print("Error: REGISTRY_CONTRACT_ADDRESS environment variable not found.")
    print("Please add REGISTRY_CONTRACT_ADDRESS=<contract_address> to your .env file")
    sys.exit(1)


def load_registry_abi() -> List[dict]:
    """
    Load the Registry contract ABI from Foundry build output.
    
    Returns:
        List of ABI items for the Registry contract
    """
    try:
        # Script is in 'py' directory, go up one level to project root to find 'out' directory
        script_dir = os.path.dirname(__file__)
        project_root = os.path.dirname(script_dir)
        registry_path = os.path.join(project_root, "out", "Registry.sol", "Registry.json")
        
        with open(registry_path, 'r') as f:
            forge_output = json.load(f)
            # Foundry output has the ABI under the 'abi' key
            if 'abi' in forge_output:
                return forge_output['abi']
            else:
                # Fallback: assume the file contains the ABI directly
                return forge_output
                
    except FileNotFoundError:
        print("Error: Registry.json file not found at 'out/Registry.sol/Registry.json'")
        print("Please ensure the Foundry build output is available or run 'forge build' from project root")
        sys.exit(1)
    except json.JSONDecodeError:
        print("Error: Invalid JSON in Registry.json file.")
        sys.exit(1)
    except KeyError as e:
        print(f"Error: Expected key not found in Registry.json: {e}")
        sys.exit(1)


def init_web3_connection() -> Optional[tuple]:
    """
    Initialize Web3 connection to Base network and Registry contract.
    
    Returns:
        Tuple of (web3_instance, registry_contract) or None if connection fails
    """
    try:
        # Initialize Web3 connection
        w3 = Web3(Web3.HTTPProvider(BASE_RPC_URL))
        
        # Test connection
        if not w3.is_connected():
            print("Warning: Could not connect to Base RPC. Validation will be skipped.")
            return None
        
        # Load Registry ABI and create contract instance
        registry_abi = load_registry_abi()
        # Convert address to checksum format
        checksum_address = w3.to_checksum_address(REGISTRY_CONTRACT_ADDRESS)
        registry_contract = w3.eth.contract(
            address=checksum_address,
            abi=registry_abi
        )
        
        print(f"✓ Connected to Base network")
        print(f"Using Registry contract: {checksum_address}")
        return w3, registry_contract
        
    except Exception as e:
        print(f"Warning: Failed to initialize Web3 connection: {e}")
        print("Validation will be skipped.")
        return None


def check_namehash_owner(registry_contract, namehash_hex: str) -> Optional[str]:
    """
    Check the owner of a namehash in the Registry contract.
    
    Args:
        registry_contract: Web3 contract instance for the Registry
        namehash_hex: Hex string of the namehash (with 0x prefix)
        
    Returns:
        Owner address as hex string, or None if error
    """
    try:
        # Convert hex string to bytes32
        namehash_bytes = bytes.fromhex(namehash_hex[2:])  # Remove 0x prefix
        
        # Call the owner function
        owner_address = registry_contract.functions.owner(namehash_bytes).call()
        
        return owner_address
        
    except Exception as e:
        # Only print the first few errors to avoid spam
        if hasattr(check_namehash_owner, '_error_count'):
            check_namehash_owner._error_count += 1
        else:
            check_namehash_owner._error_count = 1
            
        if check_namehash_owner._error_count <= 3:
            print(f"Registry error (will suppress further errors): {e}")
        elif check_namehash_owner._error_count == 4:
            print("... (suppressing additional registry errors)")
            
        return None




def namehash(name: str) -> bytes:
    """
    Calculate ENS namehash for a given name.
    
    The namehash algorithm is defined in EIP137:
    https://github.com/ethereum/EIPs/blob/master/EIPS/eip-137.md
    
    Uses the name exactly as provided, including all Unicode characters.
    
    Args:
        name: The ENS name to hash
        
    Returns:
        32-byte hash as bytes
    """
    if name == '':
        return b'\x00' * 32
    
    # Use name exactly as provided, just normalize to lowercase
    normalized_name = name.lower()
    labels = normalized_name.split('.')
    
    # Start with zero hash for empty string
    node = b'\x00' * 32
    
    # Process labels from right to left (most significant to least significant)
    for label in reversed(labels):
        # Calculate keccak256 hash of the label
        label_hash = keccak.new(digest_bits=256)
        label_hash.update(label.encode('utf-8'))
        
        # Calculate keccak256 hash of node + label_hash
        node_hash = keccak.new(digest_bits=256)
        node_hash.update(node + label_hash.digest())
        node = node_hash.digest()
    
    return node


def read_names_from_csv(input_file: str) -> List[str]:
    """
    Read names from CSV file, handling null bytes and encoding issues.
    
    Args:
        input_file: Path to input CSV file
        
    Returns:
        List of names from the CSV file
    """
    names = []
    skipped_lines = 0
    
    try:
        # First, clean the file by removing null bytes
        print("Reading and cleaning CSV file...")
        with open(input_file, 'rb') as file:
            content = file.read()
            # Remove null bytes and other problematic characters
            cleaned_content = content.replace(b'\x00', b'').replace(b'\r\n', b'\n').replace(b'\r', b'\n')
        
        # Parse the cleaned content
        from io import StringIO
        content_str = cleaned_content.decode('utf-8', errors='ignore')
        csv_file = StringIO(content_str)
        
        csv_reader = csv.DictReader(csv_file)
        
        # Get the first column name (assuming it contains the names)
        if csv_reader.fieldnames:
            name_column = csv_reader.fieldnames[0]
            print(f"Reading names from column: '{name_column}'")
        else:
            raise ValueError("CSV file appears to be empty or invalid")
        
        for row_num, row in enumerate(csv_reader, start=2):  # Start at 2 because of header
            try:
                name = row.get(name_column, "").strip() if row.get(name_column) else ""
                if name:  # Only add non-empty names
                    names.append(name)
                
                # Progress indicator for large files
                if row_num % 10000 == 0:
                    print(f"Processed {row_num:,} rows...")
                    
            except Exception as row_error:
                print(f"Skipping problematic row {row_num}: {row_error}")
                skipped_lines += 1
                continue
                    
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading CSV file: {e}")
        sys.exit(1)
    
    if skipped_lines > 0:
        print(f"⚠️  Skipped {skipped_lines:,} problematic lines")
    
    return names


def convert_names_to_namehashes(names: List[str], validate_registry: bool = True) -> Optional[List[str]]:
    """
    Convert basename handles to ENS namehashes.
    
    Each basename gets .base.eth appended before calculating the namehash.
    Uses the handle exactly as provided (no character filtering).
    Optionally validates against the Base Registry contract.
    Only returns valid (registered) namehashes.
    
    Args:
        names: List of basename handles to convert
        validate_registry: Whether to validate against Registry contract
        
    Returns:
        List of valid namehash hex strings if successful,
        None if registry validation was requested but failed
    """
    results = []
    registry_connection = None
    unregistered_count = 0
    
    print(f"\nConverting {len(names):,} basenames to ENS namehashes...")
    
    # Initialize Registry connection if validation is enabled
    if validate_registry:
        print("Initializing Registry validation...")
        registry_connection = init_web3_connection()
        if registry_connection:
            w3, registry_contract = registry_connection
            print("Registry validation enabled - unregistered names will be logged\n")
        else:
            print("❌ Registry validation failed - cannot proceed without validation")
            print("Use --no-validation flag to skip validation and process anyway")
            return None
    
    for i, name in enumerate(names):
        try:
            # Use the handle exactly as provided
            handle = name
            
            # Append .base.eth to create the full basename
            full_basename = handle + ".base.eth"
            
            # Calculate namehash of the full basename (e.g., "john.base.eth")
            name_hash = namehash(full_basename)
            
            # Convert bytes to hex string
            namehash_hex = "0x" + name_hash.hex()
            
            # Validate against Registry if connection is available
            if registry_connection:
                w3, registry_contract = registry_connection
                owner_address = check_namehash_owner(registry_contract, namehash_hex)
                
                # Check if owner is zero address (unregistered)
                if owner_address == "0x0000000000000000000000000000000000000000":
                    print(f"UNREGISTERED - Line {i+2}: '{name}' -> {full_basename}")
                    unregistered_count += 1
                # Add only registered namehashes to results
                else:
                    results.append(namehash_hex)
            else:
                # No validation - add all namehashes
                results.append(namehash_hex)
            
            # Progress indicator
            if (i + 1) % 1000 == 0:
                progress_msg = f"Converted {i + 1:,}/{len(names):,} names..."
                if registry_connection:
                    progress_msg += f" (Found {unregistered_count} unregistered, {len(results)} valid)"
                else:
                    progress_msg += f" ({len(results)} generated)"
                print(progress_msg)
                
        except Exception as e:
            print(f"Error converting name '{name}': {e}")
    
    # Final summary
    if registry_connection:
        print(f"\n✅ Valid namehashes: {len(results):,}")
        if unregistered_count > 0:
            print(f"⚠️  Unregistered basenames: {unregistered_count:,} (excluded from output)")
    else:
        print(f"\n📝 Generated namehashes: {len(results):,} (no validation performed)")
    
    return results


def write_results_to_csv(results: List[str], output_file: str):
    """
    Write namehash results to CSV file.
    
    Args:
        results: List of valid namehash hex strings
        output_file: Path to output CSV file
    """
    try:
        with open(output_file, 'w', newline='', encoding='utf-8') as file:
            csv_writer = csv.writer(file)
            
            # Write header
            csv_writer.writerow(['node'])
            
            # Write data (each namehash as a single row)
            for namehash_hex in results:
                csv_writer.writerow([namehash_hex])
            
        print(f"\nResults written to: {output_file}")
        print(f"Total valid namehashes: {len(results):,}")
        
    except Exception as e:
        print(f"Error writing to CSV file: {e}")
        sys.exit(1)


def main():
    """Main function to orchestrate the conversion process."""
    
    # Parse command line arguments
    if len(sys.argv) >= 2:
        input_file = sys.argv[1]
    else:
        input_file = "Basenames.csv"
    
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        output_file = "namehashes_output.csv"
    
    # Check for validation flag
    validate_registry = True
    if len(sys.argv) >= 4 and sys.argv[3].lower() == "--no-validation":
        validate_registry = False
    
    print("Basename ENS Namehash Converter")
    print("=" * 50)
    print(f"Input file: {input_file}")
    print(f"Output file: {output_file}")
    print("Note: Each handle will have '.base.eth' appended before namehashing")
    if validate_registry:
        print("Registry validation: ENABLED (will check against Base network)")
    else:
        print("Registry validation: DISABLED")
    print("=" * 50)
    
    # Check if input file exists
    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' does not exist.")
        sys.exit(1)
    
    try:
        # Step 1: Read names from CSV
        print("Step 1: Reading names from CSV...")
        names = read_names_from_csv(input_file)
        print(f"Found {len(names):,} valid names")
        
        # Step 2: Convert names to namehashes
        print("\nStep 2: Converting names to ENS namehashes...")
        results = convert_names_to_namehashes(names, validate_registry)
        
        # Check if conversion was successful
        if results is None:
            print("\n" + "❌" * 50)
            print("Conversion failed due to registry validation issues.")
            print("No output file was created.")
            sys.exit(1)
        
        # Step 3: Write results to output CSV
        print("\nStep 3: Writing results to CSV...")
        write_results_to_csv(results, output_file)
        
        # Summary
        print("\n" + "=" * 50)
        print("Conversion completed successfully!")
        print(f"Processed {len(names):,} basename handles")
        print(f"Valid namehashes saved to: {output_file}")
        
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
