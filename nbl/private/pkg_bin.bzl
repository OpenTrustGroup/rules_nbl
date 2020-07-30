# Copyright 2020 The GoldenRiver Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Package (BIN) helper and rules for use in projects BUILD files."""

load(
    "@io_bazel_rules_nbl//nbl/private:pkg_cmd.bzl",
    nbl_register_pkgcmds = "nbl_register_pkgcmds",
)

def _empty_impl(ctx):
    # This function is called when the rule is analyzed.
    # You may use print for debugging.
    pass

_pkg_bin = rule(implementation = _empty_impl)

def pkg_bin(**kwargs):
    kwargs["name"] = kwargs["name"] if "name" in kwargs else "default"
    _pkg_bin(name = kwargs["name"])
    nbl_register_pkgcmds(kwargs["exec"], name = kwargs["name"])
