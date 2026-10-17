# Attempt 1788

Both exact-source simulator installs completed under the 5 GiB, two-worker build. The job then exited 127 before compiling the measurement plugin or running tests because a post-build check used the system command `python3.12` instead of the staged `$ENV/bin/python3.12`. The next fresh job reuses the verified install artifacts from this job and fixes that path. No timing sample was produced.
Pinned measurement base: `f9f8e0a79f230f38da6cbb4445994ad1075ad531`; main snapshot: `7f508a8a3ab4f1a230d65abfa2543a12ca2f40a9`.
