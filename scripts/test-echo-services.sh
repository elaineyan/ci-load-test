#!/bin/bash
# Author: Huilian Yan <elaine.yan0619@hotmail.com>
# Created: 2025-09-17
# Description: Test echo services


set -e

echo "Testing http-echo services..."

# Wait for services to be fully ready
sleep 10

# Test foo service
echo "Testing foo service:"
FOO_RESPONSE=$(curl -s -H "Host: foo.localhost" http://localhost)
if [ "$FOO_RESPONSE" = "foo" ]; then
    echo "foo service working correctly - Response: '$FOO_RESPONSE'"
else
    echo "foo service failed. Expected: 'foo', Got: '$FOO_RESPONSE'"
    exit 1
fi

# Test bar service
echo "Testing bar service:"
BAR_RESPONSE=$(curl -s -H "Host: bar.localhost" http://localhost)
if [ "$BAR_RESPONSE" = "bar" ]; then
    echo "bar service working correctly - Response: '$BAR_RESPONSE'"
else
    echo "bar service failed. Expected: 'bar', Got: '$BAR_RESPONSE'"
    exit 1
fi

echo "All http-echo services are working correctly!"