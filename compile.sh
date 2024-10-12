#!/bin/bash

set -e

compile_firmware() {
    local threads=$1
    local verbose=$2

    if [ "$verbose" = "true" ]; then
        make -j$threads V=s
    else
        make -j$threads
    fi
}

main() {
    local build_threads=$1
    
    echo "Starting compilation with $build_threads threads"
    
    if compile_firmware $build_threads false; then
        echo "Compilation successful"
    else
        echo "Initial compilation failed, retrying with verbose output"
        if compile_firmware 1 true; then
            echo "Verbose compilation successful"
        else
            echo "Compilation failed"
            return 1
        fi
    fi
    
    echo "Compilation process completed"
}

main "$@"
