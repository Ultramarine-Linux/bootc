# Script to automatically expire cache tags in Quay.io after a certain period of time.
# This is used because Quay.io does not have a built-in way to
# automatically set tag expiration for a repo, unless you push an image with a label.
# But since we use Quay as a cache for our build images, Podman doesn't
# add those labels, so we need to do this ourselves.

import requests
import json
import os
import datetime

QUAY_API_URL = "https://quay.io/api/v1"
QUAY_REPO = "fyralabs/ultramarine-bootc-cache"
QUAY_TOKEN = os.getenv("QUAY_TOKEN")
EXPIRATION_DAYS = 2


def get_tags(repository):
    """
    GET /api/v1/repository/{repository}/tag/
    """
    url = f"{QUAY_API_URL}/repository/{repository}/tag/"
    headers = {"Authorization": f"Bearer {QUAY_TOKEN}"}
    body = {
        "onlyActiveTags": True,
        "limit": 200,
    }
    response = requests.get(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()


def expire_tag(repository, start_ts, tag):
    """
    PUT /api/v1/repository/{repository}/tag/{tag}
    """
    url = f"{QUAY_API_URL}/repository/{repository}/tag/{tag}"
    headers = {"Authorization": f"Bearer {QUAY_TOKEN}"}
    expiration_time = start_ts + datetime.timedelta(days=EXPIRATION_DAYS)
    body = {
        "expiration": int(expiration_time.timestamp()),
    }
    response = requests.put(url, headers=headers, json=body)
    response.raise_for_status()
    return response.json()


print("Fetching tags from Quay.io...")
tags = get_tags(QUAY_REPO)
print(json.dumps(tags, indent=2))
# {"expiration":1771222020}
for tag in tags["tags"]:
    tag_name = tag["name"]
    start_ts = datetime.datetime.fromtimestamp(tag["start_ts"])
    # Skip tags that already have an expiration set
    if "expiration" not in tag or tag["expiration"] is None:
        print(f"Setting expiration for tag {tag_name}...")
        expire_tag(QUAY_REPO, start_ts, tag_name)
