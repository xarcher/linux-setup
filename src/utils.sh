#! /bin/bash

# convert Gib to Mib
# example: echo "$(convertToMib 16G)" -> 16384
function convertToMib() {
  result_mb=0
  if [[ $1 == *M* ]]; then
    vaule_mb=$(echo $1 | sed '/sM//')
  elif [[ $1 == *G* ]]; then
    result_mb=$(echo $1 | sed 's/G/*1024/' | bc)
  fi

  echo $result_mb
}
