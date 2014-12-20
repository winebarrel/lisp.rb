lisp.rb
=======

This program is Ruby port of [Lispy](http://norvig.com/lispy.html).

### Example

```scheme
$ ./lisp.rb
lisp.rb> (+ "hello" "_" "world")
"hello_world"
lisp.rb> (+ "hello" "_" "world")
"hello_world"
lisp.rb> (print (+ "hello" "_" "world"))
"hello_world"
lisp.rb> (define x 100)
100
lisp.rb> (define f (lambda (y) (* x y)))
#<Procedure:0x007fef3a0c2188>
lisp.rb> (f 3)
300
```


### Original
Lispy (c) Peter Norvig, 2010-14

See http://norvig.com/lispy.html
