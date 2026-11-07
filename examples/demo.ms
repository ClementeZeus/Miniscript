// Fibonacci via recursion
fun fib(n) {
  if (n < 2) return n;
  return fib(n - 1) + fib(n - 2);
}

print "fib(10) = " + fib(10);

// Closures: a counter factory
fun makeCounter() {
  var count = 0;
  fun increment() {
    count = count + 1;
    return count;
  }
  return increment;
}

var counter = makeCounter();
print counter();
print counter();
print counter();

// Classes with methods, fields, and "this"
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
print p.show();
p.translate(1, 1);
print p.show();

// For loop
var sum = 0;
for (var i = 1; i <= 10; i = i + 1) {
  sum = sum + i;
}
print "sum 1..10 = " + sum;

// While loop computing a fibonacci step iteratively
var a = 1;
var b = 1;
var n = 0;
while (n < 8) {
  var t = a + b;
  a = b;
  b = t;
  n = n + 1;
}
print "8th fib step b = " + b;

// Native function + logical operators
print "clock works: " + (clock() > 0);
print "len(hello) = " + len("hello");
print (1 < 2) and (3 > 2);
print false or "fallback value";
