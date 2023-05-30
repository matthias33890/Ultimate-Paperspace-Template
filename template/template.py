import os
import argparse
import yaml
from jinja2 import Template

current_path = os.path.dirname(os.path.abspath(__file__))

target_files = {
    "control.j2": "control.sh",
    "main.j2": "main.sh",
    "env.j2": ".env"
}

if __name__ == "__main__":
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--yaml_file", help="path to the YAML file")
    parser.add_argument("--output_path", help="path to the output file")
    args = parser.parse_args()

    # Load the YAML file
    with open(args.yaml_file) as f:
        yaml_data = yaml.safe_load(f)

    for j2_file, output_filename in target_files.items():
        # Load the Jinja2 template file
        with open(os.path.join(current_path, j2_file)) as f:
            template = Template(f.read())

        # Render the template with the data
        result = template.render(yaml_data)

        # Write the output to the output file
        with open(os.path.join(args.output_path, output_filename), 'w') as f:
            f.write(result)