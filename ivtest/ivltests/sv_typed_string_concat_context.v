// IEEE 1800-2017/2023 6.16, Table 6-9, and 11.4.12.2: a
// concatenation in a string assignment context accepts string expressions
// and string literals. An all-literal concatenation is converted by that
// context, while an explicit string cast remains the route for integral
// operands. OpenTitan uses the scalar and fixed-array parameter forms below.
class sv_typed_string_source;
  static function string type_name();
    return "source";
  endfunction
endclass

class sv_typed_string_registry #(type Tregistry = sv_typed_string_source);
  static function string describe();
    // A zero-argument static string function may omit its parentheses.
    return {"type=", Tregistry::type_name};
  endfunction
endclass

// Generic class bodies are elaborated before their type parameters have a
// concrete binding. Concat legality must be deferred to the specialization,
// where these formal and property operands become string-typed.
class sv_typed_string_type_parameter_formal #(type T = int);
  static function string describe(T value);
    return {value, "!"};
  endfunction
endclass

class sv_typed_string_type_parameter_property #(type T = int);
  T value;

  function new(T initial_value);
    value = initial_value;
  endfunction

  function string describe();
    return {value, "?"};
  endfunction
endclass

// A resolved hierarchical value wins over a class with the same spelling.
// This catches speculative no-parentheses static-function type probing.
class sv_typed_string_collision_obj;
  static function string f();
    return "STATIC";
  endfunction
endclass

module sv_typed_string_collision_leaf;
  int f = 65;
endmodule

module sv_typed_string_concat_context;
  localparam string ROOT = "tb.dut";
  localparam string INDEX = "1";

  // Mirrors top_darjeeling_chip_sim's OTP acknowledgement path.
  localparam string MAIN_ACK_PATH = {
    ROOT, ".sram_otp_key_o[", INDEX, "].ack"
  };

  // An empty string literal contributes no characters after conversion.
  localparam string ALL_LITERALS = {"A", "", "B"};
  localparam string REPLICATED = {3{"xy"}};
  localparam string REPLICATED_EXPR = {2{ROOT}};
  localparam string CAST_OPERAND = {ROOT, string'(16'h002e), "leaf"};
  localparam string CAST_WHOLE = string'({8'h41, 8'h42});
  localparam string NESTED_STRING = {{ROOT, "A"}, "B"};
  localparam string NESTED_LITERALS = {{"A", "B"}, "C"};
  localparam string NESTED_CAST = {string'({"A", "B"}), "C"};
  localparam string STRING_LITERALS = {"H", ""};
  localparam logic [15:0] PACKED_LITERALS = {"H", ""};
  localparam string ZERO_REPEAT = {0{"ignored"}};

  localparam string METHOD_PARAMETER = "aB12_f";
  localparam string METHOD_NUMBER = "1_0";
  localparam string METHOD_REAL = "1.5";
  localparam string METHOD_EMPTY = "";
  localparam string METHOD_REL_A = "A";
  localparam string METHOD_REL_B = "B";
  // IEEE 1800-2017/2023 6.16 example: null bytes are removed when an
  // integral value is converted to string, leaving newline followed by A.
  localparam string METHOD_NONPRINTING = string'(12'ha41);
  localparam string METHOD_SLASH_QUOTE = "\\\"";
  localparam string PARAMETER_METHOD_STRING = {
    METHOD_PARAMETER.toupper(), ":", METHOD_PARAMETER.tolower(), ":",
    METHOD_PARAMETER.substr(1, 3)
  };
  localparam int PARAMETER_METHOD_LEN = METHOD_PARAMETER.len();
  localparam int PARAMETER_METHOD_ATOI = METHOD_NUMBER.atoi();
  localparam int PARAMETER_METHOD_ATOHEX = METHOD_NUMBER.atohex();
  localparam int PARAMETER_METHOD_ATOOCT = METHOD_NUMBER.atooct();
  localparam int PARAMETER_METHOD_ATOBIN = METHOD_NUMBER.atobin();
  localparam int PARAMETER_METHOD_COMPARE = METHOD_PARAMETER.compare("aB12_f");
  localparam int PARAMETER_METHOD_ICOMPARE = METHOD_PARAMETER.icompare("Ab12_F");
  localparam byte PARAMETER_METHOD_GETC = METHOD_PARAMETER.getc(1);
  localparam real PARAMETER_METHOD_ATOREAL = METHOD_REAL.atoreal();
  localparam int PARAMETER_METHOD_EMPTY_LEN = METHOD_EMPTY.len();
  localparam int PARAMETER_METHOD_NONPRINTING_LEN = METHOD_NONPRINTING.len();
  localparam byte PARAMETER_METHOD_NONPRINTING_0 =
    METHOD_NONPRINTING.getc(0);
  localparam byte PARAMETER_METHOD_NONPRINTING_1 =
    METHOD_NONPRINTING.getc(1);
  localparam string PARAMETER_METHOD_NONPRINTING_UPPER =
    METHOD_NONPRINTING.toupper();
  localparam string PARAMETER_METHOD_SLASH_QUOTE_SUBSTR =
    METHOD_SLASH_QUOTE.substr(0, 1);
  localparam bit PARAMETER_CONCAT_EQ_FORWARD =
    {METHOD_REL_A} == {"A", ""};
  localparam bit PARAMETER_CONCAT_EQ_REVERSE =
    {"A", ""} == {METHOD_REL_A};
  localparam bit PARAMETER_CONCAT_LT_FORWARD =
    {METHOD_REL_B} < {"A", "A"};
  localparam bit PARAMETER_CONCAT_LT_REVERSE =
    {"A", "A"} < {METHOD_REL_B};

  // Mirrors top_earlgrey_chip_sim's fixed table of hierarchical paths.
  localparam string RW_EN_PATHS[5] = '{
    {ROOT, ".lc_creator_seed_sw_rw_en_i"},
    {ROOT, ".lc_owner_seed_sw_rw_en_i"},
    {ROOT, ".lc_iso_part_sw_rd_en_i"},
    {ROOT, ".lc_iso_part_sw_wr_en_i"},
    {ROOT, ".lc_seed_hw_rd_en_i"}
  };

  // Constant string consumers require the folded value to retain string
  // identity, rather than merely carrying string-looking vector bits.
  localparam int MAIN_ACK_PATH_LEN = MAIN_ACK_PATH.len();
  localparam int CAST_OPERAND_LEN = CAST_OPERAND.len();

  int errors = 0;
  int repeat_count;
  string procedural_value;
  string method_source;
  string selected_character;
  int function_calls;
  int index_calls;
  int method_index;
  bit choose_string_arm;
  string method_compare_rhs;
  string constant_repeat_queue[$:3];
  string runtime_repeat_queue[$:3];
  sv_typed_string_type_parameter_property#(string) parameter_property;

  sv_typed_string_collision_leaf sv_typed_string_collision_obj();

  function string counted_unit();
    function_calls++;
    return "xy";
  endfunction

  function int counted_index();
    index_calls++;
    return 1;
  endfunction

  initial begin
    if (MAIN_ACK_PATH != "tb.dut.sram_otp_key_o[1].ack" ||
        MAIN_ACK_PATH_LEN != 28) begin
      $display("FAIL scalar path: <%s> len=%0d",
               MAIN_ACK_PATH, MAIN_ACK_PATH_LEN);
      errors++;
    end

    parameter_property = new("B");
    if (sv_typed_string_type_parameter_formal#(string)::describe("A") !=
          "A!" || parameter_property.describe() != "B?") begin
      $display("FAIL specialized type-parameter concatenation: <%s> <%s>",
               sv_typed_string_type_parameter_formal#(string)::describe("A"),
               parameter_property.describe());
      errors++;
    end

    if (ALL_LITERALS != "AB") begin
      $display("FAIL all-literal conversion: <%s>", ALL_LITERALS);
      errors++;
    end

    if (REPLICATED != "xyxyxy") begin
      $display("FAIL replicated string: <%s>", REPLICATED);
      errors++;
    end

    if (REPLICATED_EXPR != "tb.duttb.dut" ||
        CAST_OPERAND != "tb.dut.leaf" || CAST_OPERAND_LEN != 11 ||
        CAST_WHOLE != "AB" || NESTED_STRING != "tb.dutAB" ||
        NESTED_LITERALS != "ABC" || NESTED_CAST != "ABC") begin
      $display("FAIL expression/cast conversion: <%s> <%s> %0d <%s> <%s> <%s> <%s>",
               REPLICATED_EXPR, CAST_OPERAND, CAST_OPERAND_LEN, CAST_WHOLE,
               NESTED_STRING, NESTED_LITERALS, NESTED_CAST);
      errors++;
    end

    // Without a string expression operand the same literals retain their
    // packed integral meaning; the empty literal contributes 8'h00.
    if (STRING_LITERALS != "H" || PACKED_LITERALS !== 16'h4800) begin
      $display("FAIL dual-context literal control: <%s> %h",
               STRING_LITERALS, PACKED_LITERALS);
      errors++;
    end

    if (ZERO_REPEAT != "" || $typename(ZERO_REPEAT) != "string") begin
      $display("FAIL zero string replication: <%s> type=<%s>",
               ZERO_REPEAT, $typename(ZERO_REPEAT));
      errors++;
    end

    if (PARAMETER_METHOD_STRING != "AB12_F:ab12_f:B12" ||
        PARAMETER_METHOD_LEN != 6 || PARAMETER_METHOD_ATOI != 10 ||
        PARAMETER_METHOD_ATOHEX != 16 || PARAMETER_METHOD_ATOOCT != 8 ||
        PARAMETER_METHOD_ATOBIN != 2 || PARAMETER_METHOD_COMPARE != 0 ||
        PARAMETER_METHOD_ICOMPARE != 0 || PARAMETER_METHOD_GETC != 8'h42 ||
        PARAMETER_METHOD_ATOREAL != 1.5 ||
        PARAMETER_METHOD_EMPTY_LEN != 0 ||
        PARAMETER_METHOD_NONPRINTING_LEN != 2 ||
        PARAMETER_METHOD_NONPRINTING_0 != 8'h0a ||
        PARAMETER_METHOD_NONPRINTING_1 != 8'h41 ||
        PARAMETER_METHOD_NONPRINTING_UPPER != METHOD_NONPRINTING ||
        PARAMETER_METHOD_SLASH_QUOTE_SUBSTR != METHOD_SLASH_QUOTE ||
        !PARAMETER_CONCAT_EQ_FORWARD || !PARAMETER_CONCAT_EQ_REVERSE ||
        PARAMETER_CONCAT_LT_FORWARD || !PARAMETER_CONCAT_LT_REVERSE ||
        $typename(METHOD_NUMBER.atoi()) != "integer" ||
        $typename(METHOD_NUMBER.atohex()) != "integer" ||
        $typename(METHOD_NUMBER.atooct()) != "integer" ||
        $typename(METHOD_NUMBER.atobin()) != "integer" ||
        $typename(METHOD_PARAMETER.len()) != "int" ||
        $typename(METHOD_PARAMETER.compare("aB12_f")) != "int" ||
        $typename(METHOD_PARAMETER.icompare("Ab12_F")) != "int" ||
        $typename(METHOD_PARAMETER.getc(1)) != "byte" ||
        $typename(METHOD_REAL.atoreal()) != "real" ||
        $typename(METHOD_PARAMETER.toupper()) != "string" ||
        $typename(METHOD_PARAMETER.tolower()) != "string" ||
        $typename(METHOD_PARAMETER.substr(1, 3)) != "string") begin
      $display("FAIL parameter string methods: <%s> %0d %0d %0d %0d %0d %0d %0d %0d %0f",
               PARAMETER_METHOD_STRING, PARAMETER_METHOD_LEN,
               PARAMETER_METHOD_ATOI, PARAMETER_METHOD_ATOHEX,
               PARAMETER_METHOD_ATOOCT, PARAMETER_METHOD_ATOBIN,
               PARAMETER_METHOD_COMPARE, PARAMETER_METHOD_ICOMPARE,
               PARAMETER_METHOD_GETC, PARAMETER_METHOD_ATOREAL);
      $display("  comparisons=%b%b%b%b conversion types=<%s> <%s> <%s> <%s>",
               PARAMETER_CONCAT_EQ_FORWARD,
               PARAMETER_CONCAT_EQ_REVERSE,
               PARAMETER_CONCAT_LT_FORWARD,
               PARAMETER_CONCAT_LT_REVERSE,
               $typename(METHOD_NUMBER.atoi()),
               $typename(METHOD_NUMBER.atohex()),
               $typename(METHOD_NUMBER.atooct()),
               $typename(METHOD_NUMBER.atobin()));
      errors++;
    end

    // A constant parameter receiver does not make its arguments constant.
    // These calls must lower normally when their indices or comparison
    // operand are runtime values.
    method_index = 1;
    method_compare_rhs = "aB12_f";
    procedural_value = METHOD_PARAMETER.substr(method_index,
                                                method_index + 2);
    if (METHOD_PARAMETER.getc(method_index) != 8'h42 ||
        METHOD_PARAMETER.compare(method_compare_rhs) != 0 ||
        METHOD_PARAMETER.icompare("Ab12_F") != 0 ||
        procedural_value != "B12") begin
      $display("FAIL parameter receiver runtime arguments: %02x %0d %0d <%s>",
               METHOD_PARAMETER.getc(method_index),
               METHOD_PARAMETER.compare(method_compare_rhs),
               METHOD_PARAMETER.icompare("Ab12_F"), procedural_value);
      errors++;
    end

    if (RW_EN_PATHS[0] != "tb.dut.lc_creator_seed_sw_rw_en_i" ||
        RW_EN_PATHS[4] != "tb.dut.lc_seed_hw_rd_en_i") begin
      $display("FAIL fixed string table: <%s> <%s>",
               RW_EN_PATHS[0], RW_EN_PATHS[4]);
      errors++;
    end

    // Table 6-9 requires a cast for a concatenation of integral operands.
    procedural_value = string'({8'h41, 8'h42});
    if (procedural_value != "AB") begin
      $display("FAIL explicit integral conversion: <%s>", procedural_value);
      errors++;
    end

    // Preserve the already-supported procedural string-expression path.
    procedural_value = {ROOT, ".runtime"};
    if (procedural_value != "tb.dut.runtime") begin
      $display("FAIL procedural string concat: <%s>", procedural_value);
      errors++;
    end

    // A conditional is context-determined by the string assignment, while
    // calls in its arms retain their self-determined string result type
    // (11.4.11). This is the form used by uvm_printer::print_generic and the
    // generic-payload comparison macros in unmodified uvm-core.
    choose_string_arm = 1;
    procedural_value = choose_string_arm ? "literal" : $sformatf("%0d", 7);
    if (procedural_value != "literal") begin
      $display("FAIL true string conditional arm: <%s>", procedural_value);
      errors++;
    end
    choose_string_arm = 0;
    procedural_value = choose_string_arm ? "literal" : $sformatf("%0d", 7);
    if (procedural_value != "7") begin
      $display("FAIL call string conditional arm: <%s>", procedural_value);
      errors++;
    end

    // Width/type probing must retain the string results of built-in methods
    // and of a scoped zero-argument function whose parentheses are omitted.
    method_source = "Ab";
    procedural_value = {method_source.substr(0, 0),
                        method_source.tolower(),
                        sv_typed_string_source::type_name};
    if (procedural_value != "Aabsource" ||
	sv_typed_string_registry#(sv_typed_string_source)::describe()
	  != "type=source") begin
      $display("FAIL string call typing: <%s> <%s>", procedural_value,
               sv_typed_string_registry#(sv_typed_string_source)::describe());
      errors++;
    end

    if ($typename(method_source.len()) != "int" ||
	$typename(method_source.getc(0)) != "byte" ||
	$typename(method_source.atoi()) != "integer" ||
	$typename(method_source.compare("Ab")) != "int" ||
	$typename(method_source.substr(0, 0)) != "string") begin
      $display("FAIL string method result types: <%s> <%s> <%s> <%s> <%s>",
	       $typename(method_source.len()),
	       $typename(method_source.getc(0)),
	       $typename(method_source.atoi()),
	       $typename(method_source.compare("Ab")),
	       $typename(method_source.substr(0, 0)));
      errors++;
    end

    // OpenTitan's commercial-simulator flow uses the selected-byte spelling
    // directly. Keep this compatibility case narrower than a general
    // integral-to-string conversion.
    procedural_value = {method_source, method_source[1]};
    index_calls = 0;
    selected_character = string'(method_source[counted_index()]);
    if (procedural_value != "Abb" || selected_character != "b" ||
        selected_character.len() != 1 || index_calls != 1) begin
      $display("FAIL string byte-select conversion: <%s> <%s> len=%0d calls=%0d",
               procedural_value, selected_character,
               selected_character.len(), index_calls);
      errors++;
    end

    // Clause 11.4.12.2 permits a nonconstant replication multiplier for a
    // concatenation of string data objects.
    repeat_count = 3;
    procedural_value = {repeat_count{"xy"}};
	if (procedural_value != "xyxyxy") begin
	  $display("FAIL runtime string replication: <%s>", procedural_value);
	  errors++;
	end

    // Queue lowering keeps the bounded queue's maximum index live while its
    // value expression is evaluated. String replication must use a separately
    // allocated VVP index word rather than overwriting that bound.
    constant_repeat_queue.push_back("a");
    constant_repeat_queue.push_back("b");
    constant_repeat_queue.push_back("c");
    constant_repeat_queue.push_back({2{"u"}});
    runtime_repeat_queue.push_back("a");
    runtime_repeat_queue.push_back("b");
    runtime_repeat_queue.push_back("c");
    runtime_repeat_queue.push_back({repeat_count{"u"}});
    if (constant_repeat_queue.size() != 4 ||
        runtime_repeat_queue.size() != 4 ||
        constant_repeat_queue[0] != "a" ||
        constant_repeat_queue[3] != "uu" ||
        runtime_repeat_queue[0] != "a" ||
        runtime_repeat_queue[3] != "uuu") begin
      $display("FAIL bounded queue repeat isolation: %0d %0d",
               constant_repeat_queue.size(), runtime_repeat_queue.size());
      errors++;
    end

	// A nested all-literal string group retains the surrounding string
	// context, so its replication multiplier can be nonconstant as well.
	procedural_value = {repeat_count{{"A", "B"}}};
	if (procedural_value != "ABABAB") begin
	  $display("FAIL nested runtime string replication: <%s>",
		   procedural_value);
	  errors++;
	end

    procedural_value = string'({repeat_count{{"A", "B"}}});
    if (procedural_value != "ABABAB" ||
        {repeat_count{{"A", "B"}}} != procedural_value ||
        procedural_value != {repeat_count{{"A", "B"}}}) begin
      $display("FAIL cast/comparison string context: <%s>", procedural_value);
      errors++;
    end

    method_source = "C";
    if ({{"A", "B"}, method_source}.len() != 3) begin
      $display("FAIL nested concat method receiver");
      errors++;
    end

    function_calls = 0;
    procedural_value = {3{counted_unit()}};
    if (procedural_value != "xyxyxy" || function_calls != 1) begin
      $display("FAIL repeated operand evaluation: <%s> calls=%0d",
               procedural_value, function_calls);
      errors++;
    end
    procedural_value = {0{counted_unit()}};
    if (procedural_value != "" || function_calls != 2) begin
      $display("FAIL zero-repeat operand evaluation: <%s> calls=%0d",
               procedural_value, function_calls);
      errors++;
    end

    // Runtime replication is bounded by normal string allocation, not an
    // implementation-specific one-megabyte cutoff.
    repeat_count = 1048576;
    procedural_value = {repeat_count{"x"}};
    if (procedural_value.len() != 1048576 ||
        procedural_value.getc(1048575) != 8'h78) begin
      $display("FAIL large runtime string replication: len=%0d last=%02x",
               procedural_value.len(), procedural_value.getc(1048575));
      errors++;
    end
    procedural_value = "";

    #0;
    if ($typename({sv_typed_string_collision_obj.f, "!"}) !=
        "logic [39:0]") begin
      $display("FAIL hierarchy/class collision type: <%s>",
               $typename({sv_typed_string_collision_obj.f, "!"}));
      errors++;
    end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end
endmodule
