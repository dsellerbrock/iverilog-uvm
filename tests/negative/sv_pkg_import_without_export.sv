// Companion to ivltests/sv_pkg_export_resolve: following package
// EXPORTS when resolving a qualified name must not degrade into
// following package IMPORTS.
//
// IEEE 1800-2017 26.6 -- `outer' imports D but does NOT export it, so
// `outer::D' names nothing and must still fail to bind. A lookup that
// simply fell back to the import map would accept this.
package inner;
  parameter int unsigned D = 7;
endpackage

package outer;
  import inner::D;
  parameter int unsigned E = 3;
endpackage

module sv_pkg_import_without_export;
  localparam int unsigned X = outer::D;
  initial $display("%0d", X);
endmodule
