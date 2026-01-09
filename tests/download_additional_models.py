#!/usr/bin/env python3
"""
Download 300 additional UVL models from uvlhub.io and convert to DIMACS.
Avoids duplicates of existing models in tests/straightforward/
"""

import os
import sys
import random
import requests
import subprocess
import time
from pathlib import Path

# Configuration
PROJECT_ROOT = Path(__file__).parent.parent
UVL_DIR = PROJECT_ROOT / "tests" / "straightforward" / "uvl"
DIMACS_DIR = PROJECT_ROOT / "tests" / "straightforward" / "dimacs"
CLI_PATH = PROJECT_ROOT / "build" / "uvl2dimacs"
NUM_NEW_MODELS = 500  # Add 500 more to reach 1000 total

# Dataset URLs - Using correct Zenodo download links
DATASETS = {
    "SPLOT": "https://zenodo.org/records/12697473/files/dataset_splot_uvlhub_10.5281:zenodo.12697473.zip?download=1",
    "CDL": "https://zenodo.org/records/12697319/files/cdl_dataset_uvlhub_10.5281:zenodo.12697319.zip?download=1",
    "BusyBox": "https://zenodo.org/api/records/12697381/files-archive",
    "Financial": "https://zenodo.org/api/records/12697259/files-archive",
}

def download_dataset(name, url, output_dir):
    """Download and extract a dataset with retry logic"""
    print(f"Downloading {name} dataset from {url}...")

    # Try up to 5 times with exponential backoff
    for attempt in range(5):
        try:
            response = requests.get(url, allow_redirects=True, timeout=120)
            if response.status_code == 200:
                break
            print(f"Attempt {attempt + 1} failed: HTTP {response.status_code}")
            if attempt < 4:
                wait_time = 2 ** attempt  # Exponential backoff: 1, 2, 4, 8 seconds
                print(f"Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)
        except requests.exceptions.RequestException as e:
            print(f"Attempt {attempt + 1} failed: {e}")
            if attempt < 4:
                wait_time = 2 ** attempt
                print(f"Waiting {wait_time} seconds before retry...")
                time.sleep(wait_time)

    if response.status_code != 200:
        print(f"Failed to download {name} after 5 attempts: HTTP {response.status_code}")
        return False

    zip_path = output_dir / f"{name}.zip"
    with open(zip_path, 'wb') as f:
        f.write(response.content)

    print(f"Extracting {name}...")
    subprocess.run(['unzip', '-q', '-o', str(zip_path), '-d', str(output_dir)], check=True)
    zip_path.unlink()

    return True

def find_all_uvl_files(directory):
    """Recursively find all .uvl files"""
    uvl_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.uvl'):
                uvl_files.append(os.path.join(root, file))
    return uvl_files

def get_existing_basenames():
    """Get set of existing model basenames (without .uvl extension)"""
    existing = set()
    if UVL_DIR.exists():
        for f in UVL_DIR.glob("*.uvl"):
            existing.add(f.stem)
    return existing

def convert_to_dimacs(uvl_path, dimacs_path):
    """Convert UVL to DIMACS using CLI with -s flag"""
    try:
        result = subprocess.run(
            [str(CLI_PATH), '-s', str(uvl_path), str(dimacs_path)],
            capture_output=True,
            timeout=30
        )
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        print(f"  Timeout converting {uvl_path}")
        return False
    except Exception as e:
        print(f"  Error converting {uvl_path}: {e}")
        return False

def main():
    # Check if CLI exists
    if not CLI_PATH.exists():
        print(f"Error: CLI not found at {CLI_PATH}")
        print("Please build the project first with: make")
        sys.exit(1)

    # Create temp directory for downloads
    temp_dir = PROJECT_ROOT / "tests" / "temp_download"
    temp_dir.mkdir(exist_ok=True)

    print("=" * 60)
    print("Downloading Additional UVL Models from uvlhub.io")
    print("=" * 60)

    # Get existing basenames to avoid duplicates
    existing_basenames = get_existing_basenames()
    print(f"Found {len(existing_basenames)} existing models")
    print()

    # Download all datasets
    all_uvl_files = []
    for name, url in DATASETS.items():
        if download_dataset(name, url, temp_dir):
            dataset_files = find_all_uvl_files(temp_dir)
            print(f"Found {len(dataset_files)} UVL files in {name}")
            all_uvl_files.extend(dataset_files)
            print()

    if not all_uvl_files:
        print("Error: No UVL files found in downloaded datasets")
        sys.exit(1)

    print(f"Total UVL files available: {len(all_uvl_files)}")

    # Filter out duplicates and macOS metadata files based on basename
    new_files = []
    for uvl_file in all_uvl_files:
        basename = Path(uvl_file).stem
        # Skip macOS metadata files (starting with ._) and duplicates
        if not basename.startswith('._') and basename not in existing_basenames:
            new_files.append(uvl_file)

    print(f"New unique models available: {len(new_files)}")

    if len(new_files) < NUM_NEW_MODELS:
        print(f"Warning: Only {len(new_files)} new models available, less than requested {NUM_NEW_MODELS}")
        models_to_download = new_files
    else:
        # Randomly select NUM_NEW_MODELS files
        random.seed(42)  # For reproducibility
        models_to_download = random.sample(new_files, NUM_NEW_MODELS)

    print(f"Selecting {len(models_to_download)} new models to download and convert")
    print()

    # Process each selected file
    successful = 0
    failed = 0

    for i, uvl_file in enumerate(models_to_download, 1):
        basename = Path(uvl_file).stem
        target_uvl = UVL_DIR / f"{basename}.uvl"
        target_dimacs = DIMACS_DIR / f"{basename}.dimacs"

        # Copy UVL file
        try:
            with open(uvl_file, 'r', encoding='utf-8') as src:
                content = src.read()
            with open(target_uvl, 'w', encoding='utf-8') as dst:
                dst.write(content)
        except Exception as e:
            print(f"[{i}/{len(models_to_download)}] Failed to copy {basename}: {e}")
            failed += 1
            continue

        # Convert to DIMACS
        print(f"[{i}/{len(models_to_download)}] Converting {basename}...", end=' ')
        if convert_to_dimacs(target_uvl, target_dimacs):
            print("OK")
            successful += 1
        else:
            print("FAILED")
            failed += 1
            # Remove the UVL file if conversion failed
            target_uvl.unlink(missing_ok=True)

    # Cleanup
    print()
    print("Cleaning up temporary files...")
    subprocess.run(['rm', '-rf', str(temp_dir)], check=True)

    # Summary
    print()
    print("=" * 60)
    print("Download and Conversion Summary")
    print("=" * 60)
    print(f"Successfully processed: {successful}")
    print(f"Failed: {failed}")
    print(f"Total models in tests/straightforward/: {len(list(UVL_DIR.glob('*.uvl')))}")
    print("=" * 60)

if __name__ == "__main__":
    main()
