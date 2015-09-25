#!/usr/bin/env python3

import os
import re
import yaml, json, functools
from jinja2 import Template
import argparse

my_path = os.path.dirname(os.path.realpath(__file__))

parser = argparse.ArgumentParser(description="Reads a yaml file and outputs JSON. There are some special directives.")
parser.add_argument(
    "-c", "--config-file",
    dest="config_file",
    help="the configuration file", default=my_path + "/../etc/config.yml"
)
parser.add_argument("input_file", help="the input file to convert to json")
args = parser.parse_args()

def register_yaml_constructors():
    """
    Registers some special yaml constructors:

    !include "filename.yaml" -- includes the file at the given path relative to the input file
    !cfg_path "my.test.value" -- returns a potentially nested config value. Can be of any type.
    !cfg_str  "asdasd asd {{my.test.value}}" -- runs the argument string through jinja2 with the config as context.
    !map "filename.yaml;foo:bar" -- loop over the "bar" config value (which has to be a list) and render the template
                                    "filename.yaml" for each of its values bound to "foo".
    """

    ### yaml include support

    input_dir = os.path.dirname(os.path.realpath(args.input_file))
    def yaml_include(loader, node):
        with open(input_dir + "/" + node.value, "r") as inputfile:
            return yaml.load(inputfile)

    yaml.add_constructor("!include", yaml_include)

    ### yaml config support

    config = yaml.load(open(args.config_file, "r"))

    class NoDefaultProvided(object):
        pass

    def getattrd(obj, name, default=NoDefaultProvided):
        """
        Same as getattr(), but allows dot notation lookup
        Discussed in:
        http://stackoverflow.com/questions/11975781
        """

        def get_key(obj, key):
            return obj[key]

        try:
            return functools.reduce(get_key, name.split("."), obj)
        except AttributeError as e:
            if default != NoDefaultProvided:
                return default
            print("not found in %s", obj)
            raise

    def yaml_cfg_path(loader, node):
        val = getattrd(config, node.value)
        return val

    yaml.add_constructor("!cfg_path", yaml_cfg_path)

    def yaml_cfg_str(loader, node):
        return Template(node.value).render(config)

    yaml.add_constructor("!cfg_str", yaml_cfg_str)

    def yaml_map(loader, node):
        result = []
        (filename, *tvars) = node.value.split(';')
        for (key, val) in [x.split(':') for x in tvars]:
            for arg in config[val]:
                config[key] = arg
                with open(input_dir + "/" + filename, "r") as inputfile:
                    result.append(yaml.load(inputfile))
        return result

    yaml.add_constructor("!map", yaml_map)

register_yaml_constructors()

loaded = yaml.load(open(args.input_file, "r"))
print(json.dumps(loaded, sort_keys=True, indent=4))
