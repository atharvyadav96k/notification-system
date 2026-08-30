#!/bin/bash
set -euo pipefail

: "${DOCKER_IMAGE:?DOCKER_IMAGE is required}"
: "${AWS_REGION:?AWS_REGION is required}"
: "${SQS_QUEUE_URL:?SQS_QUEUE_URL is required}"

docker rm -f worker >/dev/null 2>&1 || true
docker pull "$DOCKER_IMAGE"

exec docker run --rm --name worker \
  -e AWS_REGION="$AWS_REGION" \
  -e SQS_QUEUE_URL="$SQS_QUEUE_URL" \
  -v /home/ec2-user:/home/ec2-user \
  "$DOCKER_IMAGE"
