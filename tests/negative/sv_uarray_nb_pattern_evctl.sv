// `q <= @(posedge clk) '{...}' -- an assignment pattern written
// non-blocking into a whole unpacked array, under an INTRA-ASSIGNMENT
// event control.
//
// The other shapes of this assignment are lowered to one non-blocking
// word assignment per pattern entry. This one cannot be: the event
// control must be waited on exactly once, and N unrolled statements
// would wait N times. So it is refused by name.
//
// It is here because of what it used to do. The r-value evaluator has
// no case for an array pattern; it pushed a zero of the l-value's width
// instead, and the code generator -- finding a whole-array l-value with
// no word index -- ABORTED on `assign_to_lvector: Assertion 'word_ix'
// failed'. The negative runner treats a signal death as a failure, not
// a rejection, so this test discriminates the diagnostic from the crash.
module sv_uarray_nb_pattern_evctl(input wire clk);

  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } cfg_t;

  cfg_t q [2];

  always @(posedge clk) q <= @(posedge clk) '{cfg_t'(8'h12), cfg_t'(8'h34)};

endmodule
