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

"""Public definitions for Nebula package rules.

All public Nebula rules, providers, and other definitions are imported and
re-exported in this file. This allows the real location of definitions
to change for easier maintenance.
"""

load(
    "@io_bazel_rules_nbl//nbl/private:pkg_far.bzl",
    _pkg_far = "pkg_far",
)

pkg_far = _pkg_far
