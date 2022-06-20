#!/bin/bash

set -eu
docker build -t ${IMAGE_TAG} . && docker push ${IMAGE_TAG}