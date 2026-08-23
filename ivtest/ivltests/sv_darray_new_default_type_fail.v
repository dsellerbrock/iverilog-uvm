// The lone default is evaluated in the context of one destination element,
// not as an untyped whole-array initializer.
module main;
  int words[];
  int aggregate[2];

  initial words = new[2]('{default:aggregate});
endmodule
