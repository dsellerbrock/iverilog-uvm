// Continuous assignment to a MEMBER of an unpacked-array element,
// inside a generate loop -- the shape OpenTitan's shared TL-UL socket
// uses for every device port:
//
//   for (genvar i = 0; i < N; i++) assign o[i].v = ...;
//
// The word index of such an l-value lives on the BASE path component
// (`o[i]'), not on the tail (`.v', which has no index). The net l-value
// elaborator read the tail, found no index, and kept a pin per array
// element -- so the assignment was routed to the whole-array path and
// rejected with "Can not assign non-array expression ... to array",
// and every loop iteration looked like another driver of the WHOLE
// array ("cannot have multiple drivers"). Both errors, one cause.
//
// This checks values, not just compilation: each element must receive
// its own data, which only holds if the index is really honored.
module sv_array_elem_member_cassign;
  typedef struct packed { logic v; logic [7:0] d; } t;

  localparam int N = 3;
  t src [N];
  t dst [N];

  // Per-element member assignments in a generate loop.
  for (genvar i = 0; i < N; i++) begin : g
    assign dst[i].v = src[i].v;
    assign dst[i].d = src[i].d + 8'd1;
  end

  initial begin
    src[0].v = 1'b1; src[0].d = 8'h10;
    src[1].v = 1'b0; src[1].d = 8'h20;
    src[2].v = 1'b1; src[2].d = 8'h30;
    #1;
    if (dst[0].v === 1'b1 && dst[0].d === 8'h11 &&
        dst[1].v === 1'b0 && dst[1].d === 8'h21 &&
        dst[2].v === 1'b1 && dst[2].d === 8'h31)
      $display("PASSED");
    else
      $display("FAILED %b/%h %b/%h %b/%h",
               dst[0].v, dst[0].d, dst[1].v, dst[1].d, dst[2].v, dst[2].d);
  end
endmodule
