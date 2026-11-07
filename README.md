---

# Miniscript

<img width="1024" height="559" alt="image" src="https://github.com/user-attachments/assets/17f9a871-e443-4d2b-b5bb-556ae88aa9ff" />

---

A small dynamically-typed scripting language — lexer, recursive-descent
parser, static resolver, and tree-walking interpreter — implemented from
scratch in plain Java. No dependencies, no build tool required beyond a
JDK (`javac`/`java`).

It follows the classic single-pass-per-stage interpreter pipeline:

```
source text
    │
    ▼
  Lexer          →  List<Token>
    │
    ▼
  Parser         →  AST (List<Stmt>, built from Expr/Stmt node classes)
    │
    ▼
  Resolver       →  variable-scope distances, static error checks
    │
    ▼
  Interpreter    →  program output / side effects
```

Each stage is a separate, independently readable pass over the data the
previous stage produced — there's no single monolithic "eval" function.

## Table of contents

- [Quick start](#quick-start)
- [Language tour](#language-tour)
- [Grammar](#grammar)
- [Architecture](#architecture)
- [Project layout](#project-layout)
- [Error model](#error-model)
- [REPL](#repl)
- [Known limitations](#known-limitations)

## Quick start

```bash
./compile.sh                  # javac everything into ./out
./run.sh examples/demo.ms     # compile + run a script
./run.sh                      # compile + drop into the REPL
```

Or by hand, no scripts:

```bash
mkdir -p out
javac -d out $(find src -name "*.java")
java -cp out com.lil.miniscript.MiniScript examples/demo.ms
```

Requires a JDK on `PATH` (any reasonably recent version — the source uses
no features newer than plain Java 8-era syntax).

## Language tour

### Variables and types

Four runtime types: `Double` (all numbers, no separate int), `String`,
`Boolean`, and `nil`. `nil` and `false` are falsy; everything else,
including `0` and `""`, is truthy.

```js
var x = 10;
var name = "ada";
var active = true;
var nothing = nil;
```

### Operators

```js
+  -  *  /  %        // arithmetic (numbers); + also concatenates strings
                     // (and auto-stringifies a number against a string)
== !=                // equality
<  <=  >  >=         // comparison (numbers only)
and or               // short-circuiting logical operators
!  -                 // unary not / negate
```

`/` by zero and comparing/arithmetic on non-numbers both raise a runtime
error rather than returning `Infinity`/`NaN`.

### Control flow

```js
if (score > 90) {
  print "A";
} else if (score > 80) {
  print "B";
} else {
  print "C";
}

while (n > 0) {
  n = n - 1;
}

for (var i = 0; i < 5; i = i + 1) {
  print i;
}
```

`for` is not a distinct runtime construct — the parser desugars it
directly into a `while` loop wrapped in a block (see `Parser.forStatement`).

### Functions and closures

```js
fun makeCounter() {
  var count = 0;
  fun increment() {
    count = count + 1;
    return count;
  }
  return increment;
}

var counter = makeCounter();
print counter(); // 1
print counter(); // 2
```

Functions are first-class values. A nested function keeps a live
reference to the `Environment` it was defined in, so returning it out of
its enclosing function and calling it later still sees (and can mutate)
that enclosing scope — a real closure, not a value snapshot.

### Classes

```js
class Point {
  init(x, y) {
    this.x = x;
    this.y = y;
  }

  show() {
    return "(" + this.x + ", " + this.y + ")";
  }

  translate(dx, dy) {
    this.x = this.x + dx;
    this.y = this.y + dy;
    return this;
  }
}

var p = Point(3, 4);
print p.show();        // (3, 4)
p.translate(1, 1);
print p.show();         // (4, 5)
```

Calling a class constructs an instance (classes implement the same
`LangCallable` interface as functions). `init` is the constructor if
present; its arity becomes the class's own arity. Fields are untyped and
created on first assignment (`this.x = ...`) — there's no field
declaration list. Methods are bound to `this` lazily, on lookup
(`LangInstance.get` calls `UserFunction.bind`), so `var f = p.show; f();`
works correctly.

> **Note:** `super` is a reserved keyword (lexed and reserved) but there
> is no `class B < A` syntax and no `super.method()` support — writing
> `super` will fail to parse with "Expect expression." Inheritance is not
> implemented.

### Native functions

Two built-ins, defined directly in `Interpreter`'s constructor:

| Function    | Arity | Returns                                      |
|-------------|-------|-----------------------------------------------|
| `clock()`   | 0     | current Unix time in seconds, as a `Double`   |
| `len(str)`  | 1     | length of a string; throws on non-string input |

```js
print "clock works: " + (clock() > 0);
print "len(hello) = " + len("hello");
```

### Comments

Single-line only, C-style:

```js
// this is a comment, runs to end of line
```

There is no block-comment syntax (`/* ... */`).

### Printing

`print` is a statement keyword, not a function:

```js
print "hello";
print 1 + 2;
```

## Grammar

Approximate EBNF for the recursive-descent parser (`Parser.java`),
expression rules ordered from lowest to highest precedence:

```
program     → declaration* EOF ;

declaration → classDecl | funDecl | varDecl | statement ;
classDecl   → "class" IDENTIFIER "{" function* "}" ;
funDecl     → "fun" function ;
function    → IDENTIFIER "(" parameters? ")" block ;
parameters  → IDENTIFIER ( "," IDENTIFIER )* ;
varDecl     → "var" IDENTIFIER ( "=" expression )? ";" ;

statement   → exprStmt | forStmt | ifStmt | printStmt
            | returnStmt | whileStmt | block ;
exprStmt    → expression ";" ;
forStmt     → "for" "(" ( varDecl | exprStmt | ";" )
              expression? ";" expression? ")" statement ;
ifStmt      → "if" "(" expression ")" statement ( "else" statement )? ;
printStmt   → "print" expression ";" ;
returnStmt  → "return" expression? ";" ;
whileStmt   → "while" "(" expression ")" statement ;
block       → "{" declaration* "}" ;

expression  → assignment ;
assignment  → ( call "." )? IDENTIFIER "=" assignment | logic_or ;
logic_or    → logic_and ( "or" logic_and )* ;
logic_and   → equality ( "and" equality )* ;
equality    → comparison ( ( "!=" | "==" ) comparison )* ;
comparison  → term ( ( ">" | ">=" | "<" | "<=" ) term )* ;
term        → factor ( ( "-" | "+" ) factor )* ;
factor      → unary ( ( "/" | "*" | "%" ) unary )* ;
unary       → ( "!" | "-" ) unary | call ;
call        → primary ( "(" arguments? ")" | "." IDENTIFIER )* ;
arguments   → expression ( "," expression )* ;
primary     → NUMBER | STRING | "true" | "false" | "nil" | "this"
            | IDENTIFIER | "(" expression ")" ;
```

Max 255 parameters per function and 255 arguments per call (checked in
`Parser.function` / `Parser.finishCall`, mirroring the JVM's own
parameter-count limit).

## Architecture

| File | Responsibility |
|---|---|
| `Lexer.java` | Hand-written scanner. Produces `Token`s, tracks line numbers for error messages, handles `//` comments, string/number literals, and all one/two-character operators. |
| `TokenType.java` | Enum of every token kind (punctuation, operators, literals, keywords). |
| `Token.java` | A single scanned token: type, lexeme, literal value, source line. |
| `Parser.java` | Recursive-descent, Pratt-style precedence climbing for expressions. Produces the AST and reports syntax errors with panic-mode recovery (`synchronize`) so one bad statement doesn't hide every other error. |
| `Expr.java` / `Stmt.java` | AST node definitions (visitor-pattern base classes for expressions and statements). |
| `Resolver.java` | Static pass over the AST, run *before* execution. Walks every scope to resolve each variable/`this` reference to a fixed lexical-scope distance, and catches: a `return` outside any function, returning a value from an `init`, `this` outside a class, reading a local variable from inside its own initializer, and redeclaring a name twice in one scope. All of these are compile-time (exit 65), not runtime, errors. |
| `Interpreter.java` | Tree-walking evaluator (visitor pattern over the AST). Owns the global environment, the two native functions, and all expression/statement semantics. |
| `Environment.java` | Chained scopes (`enclosing` pointer) backing variables; `getAt`/`assignAt` use the Resolver's precomputed distances for O(1) closure lookups instead of walking the whole chain by name. |
| `LangCallable.java` | Interface implemented by both `UserFunction` and `LangClass` — anything with an arity and a `call`. This is what lets a class be "called" to construct an instance. |
| `UserFunction.java` | A user-defined function value: closes over its defining `Environment`, and `bind()`s a fresh copy of itself with `this` defined when attached to an instance as a method. Handles the `init`-always-returns-`this` rule. |
| `LangClass.java` | A class value: a method table plus (if present) an `init` used as constructor and arity source. |
| `LangInstance.java` | An object: a class pointer plus a mutable field map. `get` checks fields first, then falls back to a bound method; `set` always just writes a field. |
| `Return.java` | Used as a control-flow exception to unwind out of nested blocks on `return` (stack-trace capture disabled in its constructor for performance). |
| `RuntimeError.java` | Carries the offending `Token` so the interpreter can report a line number. |
| `MiniScript.java` | Entry point. Wires Lexer → Parser → Resolver → Interpreter, handles CLI args (file vs. REPL), and owns the global `hadError`/`hadRuntimeError` flags that decide the process exit code. |

## Project layout

```
miniscript/
├── README.md
├── compile.sh
├── run.sh
├── examples/
│   └── demo.ms
└── src/main/java/com/lil/miniscript/
    ├── MiniScript.java      (entry point)
    ├── Lexer.java
    ├── Token.java
    ├── TokenType.java
    ├── Parser.java
    ├── Expr.java
    ├── Stmt.java
    ├── Resolver.java
    ├── Interpreter.java
    ├── Environment.java
    ├── LangCallable.java
    ├── UserFunction.java
    ├── LangClass.java
    ├── LangInstance.java
    ├── Return.java
    └── RuntimeError.java
```

`examples/demo.ms` exercises recursion (`fib`), closures (a counter
factory), classes (`Point` with fields/methods/`this`), both loop forms,
and both native functions — a good first script to read and run.

## Error model

Two failure classes, matching the standard interpreter convention (lex,
parse, and resolve errors are all "static" — they're caught before a
single line of the program runs):

| Exit code | Meaning |
|---|---|
| `64` | CLI usage error (more than one argument passed) |
| `65` | Static error — lexing, parsing, or resolving failed |
| `70` | Runtime error — type mismatch, undefined variable, division by zero, calling a non-callable, wrong argument count, missing property, etc. |

Static errors are collected and reported with `[line N] Error at '...': ...`;
the interpreter still attempts to report every syntax error it can find
in one pass (via `Parser.synchronize`) rather than stopping at the first.
Runtime errors halt execution immediately and print to stderr with the
offending line number.

## REPL

Running with no file argument drops into a line-at-a-time prompt:

```
$ ./run.sh
miniscript repl. ctrl-d to exit.
> print 1 + 2;
3
> var x = 10;
> print x * 2;
20
```

Each line is lexed/parsed/resolved/interpreted independently against the
same long-lived `Interpreter`, so `var`/`fun`/`class` declarations persist
across lines. A parse error on one line resets the error flag and does
not kill the session.

## Known limitations

Worth knowing before reaching for a feature that isn't here:

- No collection types — no arrays, lists, or maps.
- No string escape sequences — `"\n"` is a literal backslash-n, not a
  newline; strings also can't span multiple lines.
- No inheritance — `super` is reserved but unwired; there's no
  `class B < A` syntax.
- No `break`/`continue`, no ternary operator, no `switch`.
- All numbers are `double` — no distinct integer type, no bitwise ops.
- Only two native functions (`clock`, `len`) — no string/math/IO
  standard library beyond `print`.
- Single-line comments only (`//`); no block comments.

None of these are bugs — they're simply outside the current scope of the
implementation.
