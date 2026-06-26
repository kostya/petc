#!/bin/bash
set -o pipefail

export CC=clang

BUILD_STATUS=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ctrl_c() {
    echo -e "\n${YELLOW}INTERRUPTED${NC}"
    exit 130
}

trap ctrl_c SIGINT

run_step() {
    local step_name="$1"
    shift
    echo "-------------------------------------- $step_name ------------------------------------"
    "$@"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}FAILED: $step_name (exit code: $exit_code)${NC}"
        BUILD_STATUS=$exit_code
    else
        echo -e "${GREEN}PASSED: $step_name${NC}"
    fi
    echo ""
    return $exit_code
}

run_step "SPEC" crystal spec
run_step "BUILD" sh build.sh
run_step "BENCHMARK" bash -c "cd benchmark/ && ruby run.rb"
run_step "BENCHMARK BF COMPILER" bash -c "cd benchmark/brainfuck-compiler && ruby run.rb"

if [ $BUILD_STATUS -eq 0 ]; then
    echo -e "${GREEN}ALL STEPS PASSED!${NC}"
else
    echo -e "${RED}SOME STEPS FAILED (status: $BUILD_STATUS)${NC}"
fi

exit $BUILD_STATUS