# Local build attempt — missing Homebrew libffi include

Autoconf and configure passed, but the build stopped at `vvp_dpi.cc` because `ffi.h` was not on the include path. The installed Homebrew libffi was then added to CPPFLAGS/LDFLAGS. No tests ran. `localrun` reported 1,360,216,064 bytes maximum RSS.
