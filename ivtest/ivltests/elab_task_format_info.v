module elab_task_format_info;
    generate
    $warning("elab warn %0d", 7);
    $info("elab info");
    for (genvar i = 0; i < 3; i = i + 1) begin : Loop
        $info("i=%0d branch generated", i);
    end
    endgenerate
    initial begin
        $display("PASSED");
    end
endmodule
