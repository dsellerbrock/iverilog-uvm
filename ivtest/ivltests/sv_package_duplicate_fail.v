// Declaring a package name twice is an error (IEEE 1800-2017/2023 3.13).
// The second declaration used to be a bare syntax error; it names the first.
package p;
  parameter int A = 1;
endpackage

package p;
  parameter int A = 2;
endpackage

module test;
endmodule
