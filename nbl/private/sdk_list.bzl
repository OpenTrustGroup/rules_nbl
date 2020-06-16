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

"""Sdk files and sha256"""

DEFAULT_VERSION = "latest"

MIN_SUPPORTED_VERSION = "0.00"

SDK_REPOSITORIES = {
    "x.x.x": {
        "linux_amd64": ("NBL_SDK_Vx.x.x_20200429_00000000.tar.gz", "af936a98430bfd234ba78037e783f041a00f29d6311fcb1b629db0c0702fa7fd"),
    },
    "latest": {
        "linux_amd64": ("NBL_SDK_V1.1.x_20200615_000000.tar.gz", "e9fb9c4886ef3b65408452243e009675ac0c9c5a805fa095b7a001dc2b336e2b"),
    },
    "1.0.17.1": {
        "linux_amd64": ("NBL_SDK_V1.0.17.1_20200418_235526.tar.gz", "ed458cc49ddbbb9b4df878e8a2c9e4e2ca0ac84b4ce723e17cf5731a4d623f64"),
    },
}
