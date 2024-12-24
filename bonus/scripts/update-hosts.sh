#!/bin/bash
if ! grep -q "gitlab.localhost" /etc/hosts; then
    echo "127.0.0.1 gitlab.localhost" | sudo tee -a /etc/hosts
fi
