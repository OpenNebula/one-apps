#!/usr/bin/env python3

# --------------------------------------------------------------------------- #
# Copyright 2018-2019, OpenNebula Project, OpenNebula Systems                 #
#                                                                             #
# Licensed under the Apache License, Version 2.0 (the "License"); you may     #
# not use this file except in compliance with the License. You may obtain     #
# a copy of the License at                                                    #
#                                                                             #
# http://www.apache.org/licenses/LICENSE-2.0                                  #
#                                                                             #
# Unless required by applicable law or agreed to in writing, software         #
# distributed under the License is distributed on an "AS IS" BASIS,           #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.    #
# See the License for the specific language governing permissions and         #
# limitations under the License.                                              #
# --------------------------------------------------------------------------- #


import sys
import os
import argparse
import re
import json


JSON_INDENT = 4


class SaveFileError(Exception):
    """When there is an issue with writing to the context file."""
    pass


class OpenFileError(Exception):
    """When there is an issue with opening the context file."""
    pass


def get_current_context(env_prefix):
    """ Returns all env. variables where names start with 'env_prefix'. """

    context = {}
    regex = re.compile("^" + env_prefix)
    for env_var in os.environ:
        if regex.search(env_var):
            context[env_var] = os.environ[env_var]

    return context


def get_file_context(env_prefix, context_file):
    """
    Returns all env. variables from 'context_file' where names start with
    'env_prefix'.
    .
    """

    # load context file
    with open(context_file, "r") as f:
        file_context = json.load(f)

    # mark all not matching prefix
    regex = re.compile("^" + env_prefix)
    to_delete = []
    for env_var in file_context:
        if not regex.search(env_var):
            to_delete.append(env_var)

    # delete all non-matching env. vars
    for env_var in to_delete:
        del file_context[env_var]

    return file_context


def save_context(env_prefix, context_file, json_indent=JSON_INDENT):
    """
    Saves current context (env. variables with matching 'env_prefix') into the
    'context_file'.

    It will overwrite the existing file if it exists!

    Returns context.
    """

    context = get_current_context(env_prefix)
    with open(context_file, "w") as f:
        f.write(json.dumps(context, indent=json_indent))
        f.write("\n")

    return context


def load_context(env_prefix, context_file):
    """
    It loads context from the 'context_file'. It will load only those
    variables matching 'env_prefix' and which are not yet in the current
    context.

    It will NOT overwrite any variable in the current context!

    Returns result context as described above.

    NOTE:
    Because it is impossible to modify environment of the caller - the result
    from this function should dumped to the stdout as a json, which must be
    sourced later by the caller (eg: shell script).
    """

    # load context file
    file_context = get_file_context(env_prefix, context_file)

    # filter only those not in context already
    context = get_current_context(env_prefix)
    result = {}
    for file_env in file_context:
        if context.get(file_env) is None:
            result[file_env] = file_context[file_env]

    return result


def update_context(env_prefix, context_file, json_indent=JSON_INDENT):
    """
    Similar to save but it will only update the file - it will overwrite
    existing variables in the 'context_file' with those from the current
    context but it will leave the rest intact.

    Returns full content of the file as context.
    """

    # load context file
    file_context = get_file_context(env_prefix, context_file)

    # load current context
    context = get_current_context(env_prefix)

    # update file context with current context
    for env_var in context:
        file_context[env_var] = context[env_var]

    # write updated content back
    with open(context_file, "w") as f:
        f.write(json.dumps(file_context, indent=json_indent))
        f.write("\n")

    return file_context


def compare_context(env_prefix, context_file):
    """
    It will return keypairs of context variables which differs from the
    'context_file' and the current context.
    """

    # load context file
    file_context = get_file_context(env_prefix, context_file)

    # load current context
    context = get_current_context(env_prefix)

    # find all changed
    result = {}
    for env_var in context:
        if file_context.get(env_var) != context.get(env_var):
            result[env_var] = context[env_var]

    # when variable was not changed but deleted
    # TO NOTE: currently not usable because VNF is setting defaults in context.json
    #
    #for env_var in file_context:
    #    if context.get(env_var) is None:
    #        result[env_var] = ""

    return result


def error_msg(msg):
    length = 80
    line = ""
    for word in msg.split(' '):
        if (len(line + ' ' + word)) < length:
            line = line.strip() + ' ' + word
        else:
            print(line, file=sys.stderr)
            line = word
    if (line != ""):
        print(line, file=sys.stderr)


def print_result(context, output_type, json_indent=JSON_INDENT):
    """
    Prints context according to output type (the whole json, or just variable
    names - each on separate line - for simple usage).
    """

    if output_type == 'json':
        print(json.dumps(context, indent=json_indent))
    elif output_type == 'names':
        for i in context:
            print(i)
    elif output_type == 'shell':
        for i in context:
            print("%s='%s'" % (i, context[i]))


def main():
    parser = argparse.ArgumentParser(description="ONE context helper")
    parser.add_argument("-f", "--force",
                        dest="context_overwrite",
                        required=False,
                        action='store_const',
                        const=True,
                        default=False,
                        help="Forces overwrite of the file if needed")
    parser.add_argument("-e", "--env-prefix",
                        required=False,
                        metavar="<prefix>",
                        default="ONEAPP_",
                        help="Prefix of the context variables "
                        "(default: 'ONEAPP_')")
    parser.add_argument("-t", "--output-type",
                        required=False,
                        metavar="json|names|shell",
                        choices=["json", "names", "shell"],
                        default="json",
                        help="Output type (affects only load and compare) "
                        "(default: 'json')")
    parser.add_argument("context_action",
                        metavar="save|load|update|compare",
                        choices=["save", "load", "update", "compare"],
                        help=("Save/update context into the file,"
                              " or load from it,"
                              " or compare it with the current context."))
    parser.add_argument("context_file",
                        metavar="<context file>",
                        help="Filepath of the context file")

    args = parser.parse_args()

    if args.context_action == "save":
        try:
            if (os.path.isfile(args.context_file)
               and (not args.context_overwrite)):
                # file exists and no --force used...
                raise SaveFileError
        except SaveFileError:
            error_msg("ERROR: Trying to save context but the file: '" +
                      args.context_file + "' already exists!")
            error_msg("Hint 1: Try '--force' if you wish to overwrite it")
            error_msg("Hint 2: Or maybe you want to use 'update'...")
            return 1
        context = save_context(args.env_prefix, args.context_file)

    elif args.context_action == "load":
        try:
            if not os.path.isfile(args.context_file):
                raise OpenFileError
        except OpenFileError:
            error_msg("ERROR: Trying to open the context file: '" +
                      args.context_file + "' but it doesn't exist!")
            return 1
        context = load_context(args.env_prefix, args.context_file)

        # dump context values which should be sourced by caller
        print_result(context, args.output_type)

    elif args.context_action == "update":
        if os.path.isfile(args.context_file):
            # update existing
            context = update_context(args.env_prefix, args.context_file)
        else:
            # no file yet, so simply save context instead
            context = save_context(args.env_prefix, args.context_file)

    elif args.context_action == "compare":
        try:
            if not os.path.isfile(args.context_file):
                raise OpenFileError
        except OpenFileError:
            error_msg("ERROR: Trying to open the context file: '" +
                      args.context_file + "' but it doesn't exist!")
            return 1
        context = compare_context(args.env_prefix, args.context_file)

        # dump context values which should be sourced by caller
        print_result(context, args.output_type)

    return 0


if __name__ == "__main__":
    sys.exit(main())

