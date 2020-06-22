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

"""Public common provider definitions"""

PackageInfo = provider(
    doc = "Contains information about the package.",
    fields = {
        "exec": "The executable file path in package.",
    },
)

OtrpInfo = provider(
    doc = "Contains information about the otrp files in Nebula SDK.",
    fields = {
        "provision_exe": "A script to generate otrp commands (json).",
        "keystore": "A path to output generated otrp commands (json).",
        "suite": "The collection of all otrp files.",
    },
)

HostInfo = provider(
    doc = "Contains information about the host files in Nebula SDK.",
    fields = {
        "create_archive_manifest": "A host tool to create manifest for FAR.",
        "far": "A host tool to create, list, extract FAR.",
    },
)

TargetInfo = provider(
    doc = "Contains information about the target files in Nebula SDK.",
    fields = {
        "nblruncmd": "A target tool to run commands in the other world.",
        "taloaderproxyd": "A daemon enables loading TA from REE filesystems.",
    },
)

NebulaSdkInfo = provider(
    doc = "Contains information about the Nebula SDK.",
    fields = {
        "name": " The user provided name for SDK (default is 'nbl_sdk').",
        "path": "The absolute path of SDK.",
        "otrp": "A SdkOtrp provider contains otrp files.",
        "host": "A SdkHost provider contains host files.",
        "target": "A SdkTarget provider contains target files.",
    },
)

ScriptInfo = provider(
    doc = "Contains information about making runnable script.",
    fields = {
        "substitutions": "The key=val dict used for scripts substitution.",
        "runfiles": "The necessary files used for running scripts.",
    },
)
