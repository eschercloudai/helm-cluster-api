#!/usr/bin/env python3

import argparse
import collections
import os
import re
import subprocess
import yaml

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--chart', required=True, help='Chart name')
    parser.add_argument('--version', required=True, help='Chart version')
    parser.add_argument('--app-version', required=True, help='Application version')
    parser.add_argument('--path', required=True, help='Path to a directory containing customization.yaml')

    args = parser.parse_args()

    # Define directory structure.
    os.makedirs(f'{args.chart}/crds', exist_ok=True)
    os.makedirs(f'{args.chart}/templates', exist_ok=True)

    # Define chart description.
    chart = {
        'apiVersion': 'v2',
        'name': args.chart,
        'description': 'A Helm chart for deploying cluster API.',
        'type': 'application',
        'version': args.version,
        'appVersion': args.app_version,
    }

    with open(f'{args.chart}/Chart.yaml', 'w') as out:
        yaml.safe_dump(chart, out)

    # Process the official manifests.
    content = subprocess.check_output(['kubectl', 'kustomize', args.path])

    objects = yaml.safe_load_all(content)

    counts = collections.Counter()

    values = {}

    for o in objects:
        kind = o['kind']

        # CRDs go in a special place.
        if kind == 'CustomResourceDefinition':
            with open(f'{args.chart}/crds/{o["metadata"]["name"]}.yaml', 'w') as out:
                yaml.safe_dump(o, out)
            continue

        # Cluster API for some reason embed environment variables in their manifests
        # because why not, it's not like everyone else uses go templating!  Replace
        # these with a values.yaml.
        resource = yaml.safe_dump(o)

        matches = set(re.findall(r'\$\{.*?\}', resource))

        for m in matches:
            # https://regex101.com/r/8r9GZU/1
            fields = re.match(r'\$\{([A-Z0-9_]+)(?::=(.*))?\}', m)

            value = fields.group(1).lower()
            default = fields.group(2)

            if default == 'true':
                default = True
            elif default == 'false':
                default = False

            values[value] = default

            resource = resource.replace(m, '{{ .Values.' + value + ' }}')

        count = counts[kind]
        counts[kind] += 1

        with open(f'{args.chart}/templates/{kind.lower()}-{count}.yaml', 'w') as out:
            out.write(resource)

        with open(f'{args.chart}/values.yaml', 'w') as out:
            yaml.safe_dump(values, out)


if __name__ == '__main__':
    main()
