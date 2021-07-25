import json
import subprocess
import functools
import importlib.resources
from string import Template

from nixui.utils.logger import LogPipe, logger
from nixui.utils import cache
from nixui.options.attribute import Attribute


def nix_instantiate_eval(expr, strict=False):
    logger.debug(expr)
    cmd = [
        "nix-instantiate",
        '--eval',
        '-E',
        expr,
        '--json'
    ]
    if strict:
        cmd.append('--strict')

    with LogPipe('INFO') as log_pipe:
        res = subprocess.check_output(cmd, stderr=log_pipe)

    return json.loads(res)

def find_library(name):
    return importlib.resources.path('nixui.nix', f'{name}.nix')

def get_nixpkgs_version():
    return nix_instantiate_eval("with import <nixpkgs> {}; lib.version")

@functools.lru_cache()  # TODO: more efficient retain_hash_fn:  @cache(return_copy=True, retain_hash_fn=get_nixpkgs_version)
def get_all_nixos_options():
    """
    Get a JSON representation of `<nixpkgs/nixos>` options.
    The schema is as follows:
    {
      "option.name": {
        "description": String              # description declared on the option
        "loc": [ String ]                  # the path of the option e.g.: [ "services" "foo" "enable" ]
        "readOnly": Bool                   # is the option user-customizable?
        "type": String                     # either "boolean", "set", "list", "int", "float", or "string"
        "relatedPackages": Optional, XML   # documentation for packages related to the option
      }
    }
    """
    with find_library("get_all_nixos_options") as f:
        res = nix_instantiate_eval(f'import {f}', strict=True)
    # TODO: remove key from this expression, it isn't used
    return {Attribute(v['loc']): v for v in res.values()}


@cache.cache(return_copy=True, retain_hash_fn=cache.first_arg_path_hash_fn)
def get_modules_defined_attrs(module_path):
    with find_library("get_modules_defined_attrs") as f:
        leaves = nix_instantiate_eval(f'import {f} {module_path}', strict=True)

    return {
        Attribute(v['name']): {"position": v['position']}
        for v in leaves
    }


def eval_attribute(module_path, attribute):
    with find_library("module_path") as f:
        return nix_instantiate_eval(f'import {f} {module_path} {attribute}')
