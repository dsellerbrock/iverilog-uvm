module issue1257_vpi_signed;
    logic [6:0] result;

    initial begin
        result = $signed(16'h1234);
        if ($bits($signed(16'h1234)) != 7)
            $fatal(1, "VPI_SIGNED_BITS=%0d", $bits($signed(16'h1234)));
        if (result !== 7'h55)
            $fatal(1, "VPI_SIGNED_VALUE=%h", result);
        $display("VPI_SIGNED_BITS=%0d VALUE=%h",
                 $bits($signed(16'h1234)), result);
        $display("PASSED");
        $finish;
    end
endmodule
