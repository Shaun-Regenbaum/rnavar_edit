#!/usr/bin/env bash
set -euo pipefail

# Build and push all containers

build_push() {
    GENOME=$1
    SNPEFF_CACHE_VERSION=$2
    SNPEFF_TAG=$3

    docker build \
        . \
        -t nfcore/snpeff:${SNPEFF_TAG}.${GENOME} \
        --build-arg GENOME=${GENOME} \
        --build-arg SNPEFF_CACHE_VERSION=${SNPEFF_CACHE_VERSION} \
        --build-arg SNPEFF_TAG=${SNPEFF_TAG}

    docker push nfcore/snpeff:${SNPEFF_TAG}.${GENOME}
}
build_push "CanFam3.1" "99"  "5.1"
build_push "GRCh37"    "87"  "5.1"
build_push "GRCh38"    "105" "5.1"
build_push "GRCm38"    "99"  "5.1"
build_push "GRCm39"    "105" "5.1"
build_push "R64-1-1"   "105" "5.1"
build_push "UMD3.1"    "75"  "5.1"
build_push "WBcel235"  "105" "5.1"
