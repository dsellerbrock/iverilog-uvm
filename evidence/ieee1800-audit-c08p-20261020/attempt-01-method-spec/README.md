# IEEE 1800-2023 §8.20 method override specifier probe

Probe source follows Example 3 on 2023 pp.197–198, retaining its legal `:initial`, `:extends`, and `:final` declarations; legal method bodies print tags, and concrete subclasses implement the example's pure method so the module can call every represented method. Five separate negatives correspond to the example's illegal declarations. Three more test mutually exclusive `:initial`/`:extends`, `:final` on a pure method, and overriding a non-virtual `:final` method.

Compile and run the legal case under `-g2023`; compile each negative under `-g2023`; compile the legal case under `-g2017`, where the 2023 syntax should be rejected. Every compiler and runtime invocation has a 30-second timeout. Compare the successful runtime output exactly.

Dedupe is recorded in `dedupe-open-closed.txt`; #455 was reread directly, including its completion comment. It claims this area is fixed and is the only directly relevant result. Other search hits (#619, #102, #15, #27) concern constructor `super.new()` rules, fork capture, UVM callbacks, or runtime stubs, not method override specifiers.

## Archive integrity

- `results-3503.tar.gz`: 2544 bytes; SHA-256 `5ad14fd6b50f65ca2e0dda4644f0264c90d3810785079ec594dfcf80bbf393d3`.
