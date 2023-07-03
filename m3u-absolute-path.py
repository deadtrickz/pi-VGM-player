#!/usr/bin/env python3

import argparse
import os
import pathlib

def convert_m3u_to_absolute_paths(m3u_file):
    base_path = pathlib.Path(os.path.dirname(m3u_file)).resolve()
    print(f"Base path: {base_path}")
    with open(m3u_file, 'r') as file:
        lines = file.readlines()

    with open(m3u_file, 'w') as file:
        for line in lines:
            line = line.strip()
            # Skip blank lines and comments
            if not line or line.startswith('#'):
                file.write(line + '\n')
                continue
            # Convert relative paths to absolute
            path = pathlib.Path(line)
            print(f"Original path: {path}")
            if not path.is_absolute():
                path = base_path / path
            print(f"Converted path: {path}")
            file.write(str(path) + '\n')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Convert relative paths in M3U file to absolute paths.')
    parser.add_argument('m3u_file', help='The M3U file to convert.')
    args = parser.parse_args()

    convert_m3u_to_absolute_paths(args.m3u_file)