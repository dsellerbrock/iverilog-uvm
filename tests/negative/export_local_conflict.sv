// IEEE 1800-2017 26.6: `export P1::x` is a genuine use of the wildcard
// import of x, so a LATER local declaration of x in the same package
// conflicts with it -- even though the declaration comes after the
// export (vendored ivtest sv_export_fail5). The export must pin the
// import so add_local_symbol sees the conflict.
package P1;
  integer x = 123;
endpackage
package P2;
  import P1::*;
  export P1::x;
  integer x = 456;  // error: x already imported (and exported)
endpackage
module export_local_conflict;
  import P2::x;
endmodule
