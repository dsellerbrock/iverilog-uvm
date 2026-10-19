# Slurm build attempt 2617

The isolated reference checkout stopped before compilation. It cloned the
`ca559fd` template with Git's shared object store, then selected `d9caaaea`.
The template did not contain all blobs needed to transition its working index
across the #640 merge; the clean-tree assertion found 70 deleted paths. A
subsequent reset reported missing blobs for those paths. No candidate binary or
performance result was produced. The template checkout was not modified.

The retry stages a checksummed source archive for `d9caaaea` and the exact
submodule snapshots, avoiding reliance on the incomplete shared object cache.
