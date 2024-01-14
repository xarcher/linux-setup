#! /bin/bash

. utils.sh

swap_size=16G
data=$(convertToMib ${swap_size})
echo "test ok: ${data}"