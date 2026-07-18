// M13B negative: config declarations select library cells (design /
// instance use clauses), so skipping one changes design meaning.
// Library-based cell binding is not implemented: hard error, not a
// skip.
module config_block;
endmodule

config cfg1;
  design work.config_block;
endconfig
