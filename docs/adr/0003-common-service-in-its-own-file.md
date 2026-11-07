# 0003 — The common service is a separate file

Status: accepted

`compose/common.yml` holds the profile-less, image-less, build-less `common`
service. A same-file parent would pass its profile and build target to every
stack, so `--profile base` would select all stacks. Host values never enter this
file; they live in the ignored host overlay.
