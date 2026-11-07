# 0001 — One repository, co-located modules

Status: accepted

The repository keeps the base image and every stack in one tree, but each image
is a module with its own manifest, compose fragment, bake fragment, tests and
docs. A module owns its facts; shared sources (`versions.env`, manifests) are
read by tooling. Stack directories are leaves: they depend on the base contract
and never on a sibling stack.
