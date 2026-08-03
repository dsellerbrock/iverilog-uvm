`begin_keywords "1800-2012"

module main;
  parameter string MemInitFile = "";
  logic [7:0] mem [2];

  // OpenTitan leaves this simulation helper outside `ifndef SYNTHESIS, but
  // its only live statement disappears when the initialization file is the
  // default empty string. Synthesis should drop the inert process silently.
  initial begin
    if (MemInitFile != "")
      $readmemh(MemInitFile, mem);
  end

  (* ivl_synthesis_off *)
  initial begin
    #1;
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
