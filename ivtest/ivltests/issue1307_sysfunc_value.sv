module issue1307_sysfunc_value;
    integer result;

    initial begin
        result = $answer();
        if (result !== 42)
            $fatal(1, "SYSFUNC_RESULT=%0d", result);
        $display("SYSFUNC_RESULT=%0d", result);
        $display("PASSED");
        $finish;
    end
endmodule
