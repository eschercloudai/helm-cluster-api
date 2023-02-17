#!/usr/bin/env python3

import sys

def main():
    chunks = []

    with open('charts/cluster-api/values.yaml.tmpl') as file:
        chunks.append(file.read())

    for chart in sys.argv[1:]:
        chunk = [f"{chart}:\n"]

        with open(f'charts/{chart}/values.yaml') as file:
            chunk.extend(f"  {x}" for x in file.readlines())

        chunks.append(''.join(chunk))

    with open('charts/cluster-api/values.yaml', 'w') as file:
        file.write('\n'.join(chunks))

if __name__ == '__main__':
    main()
