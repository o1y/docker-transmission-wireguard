#!/bin/bash

trap 'exit 0' TERM

sleep 180

while true; do
    handshake_output=$(wg show wg0 latest-handshakes 2>&1)

    if [ $? -ne 0 ]; then
        echo "Health check: wg0 interface lost, exiting"
        kill 1
        exit 1
    fi

    latest_handshake=$(echo "$handshake_output" | awk 'NR==1 {print $2}')

    if [ -z "$latest_handshake" ] || ! [[ "$latest_handshake" =~ ^[0-9]+$ ]] || [ "$latest_handshake" -eq 0 ]; then
        echo "Health check: no valid handshake, exiting"
        kill 1
        exit 1
    fi

    handshake_age=$(( $(date +%s) - latest_handshake ))

    if [ "$handshake_age" -gt 180 ]; then
        echo "Health check: stale handshake (${handshake_age}s), verifying with ping..."
        if ! ping -I wg0 -c 3 -W 5 1.1.1.1 > /dev/null 2>&1 \
        && ! ping -6 -I wg0 -c 3 -W 5 2606:4700:4700::1111 > /dev/null 2>&1; then
            echo "Health check: tunnel unreachable, exiting"
            kill 1
            exit 1
        fi
        echo "Health check: tunnel verified, handshake refreshed"
    fi

    sleep 60
done
