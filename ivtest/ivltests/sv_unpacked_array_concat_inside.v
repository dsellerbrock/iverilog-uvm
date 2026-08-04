// IEEE 1800-2017 10.10 and 11.4.13: an unpacked array concatenation
// takes its element type and shape from the assignment context, and a
// fixed unpacked array used as an inside set contributes every element.
module main;
  typedef enum logic [3:0] {
    BidirStd     = 4'h1,
    BidirTol     = 4'h3,
    DualBidirTol = 4'h7,
    BidirOd      = 4'hc,
    Other        = 4'he
  } pad_type_e;

  pad_type_e src0, src1, src2, src3;
  pad_type_e ascending [0:3];
  wire pad_type_e descending [3:0];
  logic [3:0] wildcard_src0, wildcard_src1;
  wire logic [3:0] wildcard_values [0:1];

  assign ascending  = {src0, src1, src2, src3};
  assign descending = {src0, src1, src2, src3};
  assign wildcard_values = {wildcard_src0, wildcard_src1};

  task automatic check(input string label, input logic got,
                       input logic expected);
    if (got !== expected) begin
      $display("FAILED -- %s: got %b expected %b", label, got, expected);
      $finish(1);
    end
  endtask

  initial begin
    src0 = BidirStd;
    src1 = BidirTol;
    src2 = DualBidirTol;
    src3 = BidirOd;
    wildcard_src0 = 4'b10x1;
    wildcard_src1 = 4'b0110;
    #1;

    // Array-concatenation elements map left-to-right onto the array's
    // declared left-to-right order, independent of index direction.
    check("ascending[0]",  ascending[0]  == BidirStd,     1);
    check("ascending[1]",  ascending[1]  == BidirTol,     1);
    check("ascending[2]",  ascending[2]  == DualBidirTol, 1);
    check("ascending[3]",  ascending[3]  == BidirOd,      1);
    check("descending[3]", descending[3] == BidirStd,     1);
    check("descending[2]", descending[2] == BidirTol,     1);
    check("descending[1]", descending[1] == DualBidirTol, 1);
    check("descending[0]", descending[0] == BidirOd,      1);

    check("ascending hit first", BidirStd inside {ascending}, 1);
    check("ascending hit middle", DualBidirTol inside {ascending}, 1);
    check("ascending hit last", BidirOd inside {ascending}, 1);
    check("ascending miss", Other inside {ascending}, 0);
    check("descending hit", BidirTol inside {descending}, 1);
    check("mixed set array hit", BidirOd inside {Other, ascending}, 1);
    check("mixed set scalar hit", Other inside {ascending, Other}, 1);
    check("array set wildcard low", 4'b1001 inside {wildcard_values}, 1);
    check("array set wildcard high", 4'b1011 inside {wildcard_values}, 1);
    check("array set wildcard miss", 4'b1101 inside {wildcard_values}, 0);

    // Both the continuous assignment and the membership test must observe
    // live values, rather than folding the initializer once at elaboration.
    src1 = Other;
    #1;
    check("updated word", ascending[1] == Other, 1);
    check("updated set hit", Other inside {ascending}, 1);
    check("updated set miss", BidirTol inside {ascending}, 0);

    $display("PASSED");
  end
endmodule
