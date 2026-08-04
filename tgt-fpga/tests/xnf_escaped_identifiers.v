module xnf_identifier_child(
  input  wire a,
  input  wire b,
  output wire y
);
  and gate(y, a, b);
endmodule

module xnf_escaped_identifiers(
  input  wire \a,b ,
  input  wire __ivl_xnf_612C62,
  output wire y
);
  xnf_identifier_child \inst,FIELD=BAD  (
    .a(\a,b ),
    .b(__ivl_xnf_612C62),
    .y(y)
  );
endmodule
