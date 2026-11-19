// A package checker needs a preceding import for an unqualified use.
package hidden3361;
  checker unimported_checker; endchecker
  checker late_checker; endchecker
  checker bind_checker; endchecker
endpackage

module issue3361_unimported;
  unimported_checker u();
endmodule

module issue3361_late_import;
  late_checker u();
  import hidden3361::*;
endmodule

// A bind cannot make a wildcard import candidate locally visible (23.11).
module issue3361_bind_target;
  import hidden3361::*;
endmodule

bind issue3361_bind_target bind_checker u();

// An enclosing instance does not add names to the checker's lexical scope.
package caller3361;
  checker outer;
    caller_checker u();
  endchecker
endpackage

module issue3361_nonlexical;
  checker caller_checker; endchecker
  caller3361::outer u();
endmodule
