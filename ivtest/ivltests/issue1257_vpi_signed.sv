module issue1257_vpi_signed;
    logic [15:0] argument = 16'h1234;
    logic [6:0] result;

    initial begin
        if ($bits($signed(argument)) != 7)
            $fatal(1, "SIGNED_BITS=%0d", $bits($signed(argument)));

        result = $signed(argument);
        if (result !== 7'h55)
            $fatal(1, "SIGNED_RESULT=%h", result);

        if ($bits($unsigned(argument)) != 16 || $unsigned(argument) !== argument)
            $fatal(1, "UNSIGNED_BUILTIN_BITS=%0d VALUE=%h",
                   $bits($unsigned(argument)), $unsigned(argument));

        $display("SIGNED_BITS=%0d RESULT=%h", $bits($signed(argument)), result);
        $display("UNSIGNED_BITS=%0d VALUE=%h",
                 $bits($unsigned(argument)), $unsigned(argument));
        $display("PASSED");
        $finish;
    end
endmodule
