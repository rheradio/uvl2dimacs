#!/usr/bin/env python3
"""
Script to download 200 random UVL models from uvlhub.io and convert them to DIMACS
"""

import os
import sys
import random
import requests
import zipfile
import shutil
from pathlib import Path
import subprocess
import time

# Dataset URLs to download from
DATASETS = [
    {
        'url': 'https://www.uvlhub.io/datasets/download/20',  # Complete SPLOT dataset
        'name': 'splot'
    },
    {
        'url': 'https://www.uvlhub.io/datasets/download/11',  # CDL
        'name': 'cdl'
    },
    {
        'url': 'https://www.uvlhub.io/datasets/download/14',  # BusyBox
        'name': 'busybox'
    },
    {
        'url': 'https://www.uvlhub.io/datasets/download/7',   # Financial Services
        'name': 'financial'
    }
]

def download_dataset(url, output_path):
    """Download a dataset from uvlhub.io"""
    print(f"Downloading from {url}...")
    response = requests.get(url, stream=True, allow_redirects=True)
    response.raise_for_status()

    with open(output_path, 'wb') as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
    print(f"Downloaded to {output_path}")

def extract_zip(zip_path, extract_to):
    """Extract a zip file"""
    print(f"Extracting {zip_path}...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to)
    print(f"Extracted to {extract_to}")

def find_uvl_files(directory):
    """Recursively find all UVL files in a directory"""
    uvl_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.uvl'):
                uvl_files.append(os.path.join(root, file))
    return uvl_files

def main():
    # Setup paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    temp_dir = script_dir / 'temp_downloads'
    uvl_output_dir = script_dir / 'straightforward' / 'uvl'
    dimacs_output_dir = script_dir / 'straightforward' / 'dimacs'
    cli_path = project_root / 'build' / 'uvl2dimacs'

    # Create directories
    temp_dir.mkdir(exist_ok=True)
    uvl_output_dir.mkdir(parents=True, exist_ok=True)
    dimacs_output_dir.mkdir(parents=True, exist_ok=True)

    # Check if CLI exists
    if not cli_path.exists():
        print(f"Error: CLI not found at {cli_path}")
        print("Please build the project first with: make")
        sys.exit(1)

    # Download and extract datasets
    all_uvl_files = []
    for dataset in DATASETS:
        zip_path = temp_dir / f"{dataset['name']}.zip"
        extract_path = temp_dir / dataset['name']

        try:
            # Download dataset
            download_dataset(dataset['url'], zip_path)

            # Extract
            extract_zip(zip_path, extract_path)

            # Find UVL files
            uvl_files = find_uvl_files(extract_path)
            print(f"Found {len(uvl_files)} UVL files in {dataset['name']}")
            all_uvl_files.extend(uvl_files)

        except Exception as e:
            print(f"Error processing dataset {dataset['name']}: {e}")
            continue

    print(f"\nTotal UVL files found: {len(all_uvl_files)}")

    # Randomly select 200 files
    if len(all_uvl_files) < 200:
        print(f"Warning: Only found {len(all_uvl_files)} files, using all of them")
        selected_files = all_uvl_files
    else:
        selected_files = random.sample(all_uvl_files, 200)

    print(f"Selected {len(selected_files)} files for conversion")

    # Process each file
    successful_conversions = 0
    failed_conversions = []

    for i, source_file in enumerate(selected_files, 1):
        # Generate a unique name based on the original filename
        original_name = Path(source_file).stem
        # Clean the name to avoid conflicts
        clean_name = original_name.replace(' ', '_').replace('(', '').replace(')', '')
        output_name = f"{clean_name}_{i:03d}"

        uvl_dest = uvl_output_dir / f"{output_name}.uvl"
        dimacs_dest = dimacs_output_dir / f"{output_name}.dimacs"

        # Copy UVL file
        try:
            shutil.copy2(source_file, uvl_dest)
            print(f"[{i}/{len(selected_files)}] Copied {original_name} -> {output_name}.uvl")

            # Convert to DIMACS using CLI with -s flag
            result = subprocess.run(
                [str(cli_path), '-s', str(uvl_dest), str(dimacs_dest)],
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                print(f"[{i}/{len(selected_files)}] Converted {output_name}.uvl -> {output_name}.dimacs")
                successful_conversions += 1
            else:
                print(f"[{i}/{len(selected_files)}] Failed to convert {output_name}.uvl")
                print(f"  Error: {result.stderr}")
                failed_conversions.append(output_name)
                # Remove the UVL file if conversion failed
                uvl_dest.unlink()

        except Exception as e:
            print(f"[{i}/{len(selected_files)}] Error processing {output_name}: {e}")
            failed_conversions.append(output_name)
            if uvl_dest.exists():
                uvl_dest.unlink()

    # Cleanup temp directory
    print("\nCleaning up temporary files...")
    shutil.rmtree(temp_dir)

    # Summary
    print("\n" + "="*60)
    print(f"Summary:")
    print(f"  Total files processed: {len(selected_files)}")
    print(f"  Successful conversions: {successful_conversions}")
    print(f"  Failed conversions: {len(failed_conversions)}")
    print("="*60)

    if failed_conversions:
        print("\nFailed files:")
        for name in failed_conversions[:10]:  # Show first 10
            print(f"  - {name}")
        if len(failed_conversions) > 10:
            print(f"  ... and {len(failed_conversions) - 10} more")

    print(f"\nUVL files saved to: {uvl_output_dir}")
    print(f"DIMACS files saved to: {dimacs_output_dir}")

if __name__ == '__main__':
    main()
