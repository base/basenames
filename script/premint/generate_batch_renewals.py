#!/usr/bin/env python3
"""
Script to generate a CSV file with token ids and 5-year duration for premint names.

# Default 5-year duration
python3 generate_batch_renewals.py premint1

# Custom 1-year duration
python3 generate_batch_renewals.py premint1 -d 1

# Custom 2.5-year duration with custom output
python3 generate_batch_renewals.py premint1 -o premint1_batch.csv --duration 2.5

# Show help
python3 generate_batch_renewals.py --help
"""

import csv
import argparse
from pathlib import Path
from Crypto.Hash import keccak

def keccak256_to_uint(data: str) -> int:
    """
    Calculate keccak256 hash of a string and return as uint.
    
    Args:
        data: String to hash
        
    Returns:
        Integer representation of the keccak256 hash
    """
    # Convert string to bytes and calculate keccak256 hash
    k = keccak.new(digest_bits=256)
    k.update(data.encode('utf-8'))
    
    # Convert hash bytes to integer
    return int.from_bytes(k.digest(), byteorder='big')

def calculate_duration_in_seconds(years: float) -> int:
    """
    Calculate duration in seconds using 365.25 days per year.
    
    Args:
        years: Number of years
        
    Returns:
        Duration in seconds
    """
    days_per_year = 365.25
    seconds_per_day = 24 * 60 * 60  # 86400 seconds
    
    return int(days_per_year * years * seconds_per_day)

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Generate CSV file with token ids and duration for premint names"
    )
    parser.add_argument(
        "input_file",
        help="Path to the input file containing names (one per line)"
    )
    parser.add_argument(
        "-o", "--output",
        default="premint_hashes.csv",
        help="Output CSV file path (default: premint_hashes.csv)"
    )
    parser.add_argument(
        "-d", "--duration",
        type=float,
        default=5.0,
        help="Duration in years (default: 5.0)"
    )
    return parser.parse_args()

def load_excluded_names(script_dir: Path) -> set:
    """Load names to exclude from the lostnames file."""
    lostnames_file = script_dir / "lostnames"
    excluded_names = set()
    
    if lostnames_file.exists():
        with open(lostnames_file, 'r') as f:
            for line in f:
                name = line.strip()
                if name:
                    excluded_names.add(name.lower())  # Store in lowercase for case-insensitive comparison
    
    return excluded_names

def main():
    """Main function to generate the CSV file."""
    
    # Parse command line arguments
    args = parse_arguments()
    
    # Path to the input and output files
    input_file = Path(args.input_file)
    output_file = Path(args.output)
    script_dir = Path(__file__).parent
    
    # Check if input file exists
    if not input_file.exists():
        print(f"Error: Input file '{input_file}' not found.")
        return 1
    
    # Load excluded names from lostnames file
    excluded_names = load_excluded_names(script_dir)
    print(f"Loaded {len(excluded_names)} excluded names from lostnames file")
    
    # Calculate duration in seconds
    duration_seconds = calculate_duration_in_seconds(args.duration)
    print(f"Duration: {args.duration} years ({duration_seconds} seconds)")
    print(f"Input file: {input_file}")
    print(f"Output file: {output_file}")
    
    # Read names from input file and collect unique IDs
    seen_ids = set()
    unique_entries = []
    duplicate_names = []
    excluded_names_found = []
    
    with open(input_file, 'r') as infile:
        for line_num, line in enumerate(infile, 1):
            name = line.strip()
            if name:  # Skip empty lines
                # Check if name is in excluded list (case-insensitive)
                if name.lower() in excluded_names:
                    excluded_names_found.append((line_num, name))
                    continue
                
                name_id = keccak256_to_uint(name)
                if name_id not in seen_ids:
                    seen_ids.add(name_id)
                    unique_entries.append((name_id, duration_seconds, name))
                else:
                    duplicate_names.append((line_num, name))
    
    # Write CSV with unique entries only
    with open(output_file, 'w', newline='') as outfile:
        csv_writer = csv.writer(outfile)
        
        # Write header
        csv_writer.writerow(['id', 'duration'])
        
        # Write unique entries
        for name_id, duration, _ in unique_entries:
            csv_writer.writerow([name_id, duration])
    
    # Report results
    total_names = sum(1 for line in open(input_file) if line.strip())
    unique_count = len(unique_entries)
    duplicate_count = len(duplicate_names)
    excluded_count = len(excluded_names_found)
    
    print(f"CSV file generated: {output_file}")
    print(f"Total names processed: {total_names}")
    print(f"Unique entries written: {unique_count}")
    print(f"Duplicates found and skipped: {duplicate_count}")
    print(f"Excluded names found and skipped: {excluded_count}")
    
    if duplicate_names:
        print("\nDuplicate names found:")
        for line_num, name in duplicate_names:
            print(f"  Line {line_num}: {name}")
    else:
        print("No duplicates found.")
    
    if excluded_names_found:
        print("\nExcluded names found (from lostnames):")
        for line_num, name in excluded_names_found:
            print(f"  Line {line_num}: {name}")
    else:
        print("No excluded names found.")
    return 0

if __name__ == "__main__":
    exit_code = main()
    exit(exit_code)
