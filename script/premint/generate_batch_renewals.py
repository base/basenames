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

def main():
    """Main function to generate the CSV file."""
    
    # Parse command line arguments
    args = parse_arguments()
    
    # Path to the input and output files
    input_file = Path(args.input_file)
    output_file = Path(args.output)
    
    # Check if input file exists
    if not input_file.exists():
        print(f"Error: Input file '{input_file}' not found.")
        return 1
    
    # Calculate duration in seconds
    duration_seconds = calculate_duration_in_seconds(args.duration)
    print(f"Duration: {args.duration} years ({duration_seconds} seconds)")
    print(f"Input file: {input_file}")
    print(f"Output file: {output_file}")
    
    # Read names from input file and generate CSV
    with open(input_file, 'r') as infile, open(output_file, 'w', newline='') as outfile:
        csv_writer = csv.writer(outfile)
        
        # Write header
        csv_writer.writerow(['id', 'duration'])
        
        # Process each name
        for line in infile:
            name = line.strip()
            if name:  # Skip empty lines
                name_id = keccak256_to_uint(name)
                csv_writer.writerow([name_id, duration_seconds])
    
    print(f"CSV file generated: {output_file}")
    print(f"Processed {sum(1 for line in open(input_file) if line.strip())} names")
    return 0

if __name__ == "__main__":
    exit_code = main()
    exit(exit_code)
