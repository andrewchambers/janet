# Copyright 2017-2019 (C) Calvin Rose

(do

  (var *should-repl* false)
  (var *no-file* true)
  (var *quiet* false)
  (var *raw-stdin* false)
  (var *handleopts* true)
  (var *exit-on-error* true)
  (var *colorize* true)
  (var *implicit* nil)

  (if-let [jp (os/getenv "JANET_PATH")] (set module/*syspath* jp))

  # Flag handlers
  (def handlers :private
    {"h" (fn [&]
           (print "usage: " (get process/args 0) " [options] script args...")
           (print
             `Options are:
  -h : Show this help
  -v : Print the version string
  -s : Use raw stdin instead of getline like functionality
  -e code : Execute a string of janet
  -r : Enter the repl after running all scripts
  -p : Keep on executing if there is a top level error (persistent)
  -q : Hide prompt, logo, and repl output (quiet)
  -m syspath : Set system path for loading global modules
  -c source output : Compile janet source code into an image
  -n : Disable ANSI color output in the repl
  -l path : Execute code in a file before running the main script
  -I : Implicitly wrap input lines not starting with '(' with parens.
  -i form : Like -I but insert form as the first call argument.
  -- : Stop handling options`)
           (os/exit 0)
           1)
     "v" (fn [&] (print janet/version "-" janet/build) (os/exit 0) 1)
     "s" (fn [&] (set *raw-stdin* true) (set *should-repl* true) 1)
     "r" (fn [&] (set *should-repl* true) 1)
     "p" (fn [&] (set *exit-on-error* false) 1)
     "q" (fn [&] (set *quiet* true) 1)
     "n" (fn [&] (set *colorize* false) 1)
     "n" (fn [&] (set *colorize* false) 1)
     "m" (fn [i &] (set module/*syspath* (get process/args (+ i 1))) 2)
     "c" (fn [i &]
           (def e (require (get process/args (+ i 1))))
           (spit (get process/args (+ i 2)) (make-image e))
           (set *no-file* false)
           3)
     "i" (fn [i &]
           (set *implicit* (string/format "%s " (get process/args (+ i 1)))) 2)
     "I" (fn [&] (set *implicit* "") 1)
     "-" (fn [&] (set *handleopts* false) 1)
     "l" (fn [i &]
           (import* (get process/args (+ i 1))
                    :prefix "" :exit *exit-on-error*)
           2)
     "e" (fn [i &]
           (set *no-file* false)
           (eval-string (get process/args (+ i 1)))
           2)})

  (defn- dohandler [n i &]
    (def h (get handlers n))
    (if h (h i) (do (print "unknown flag -" n) ((get handlers "h")))))

  # Process arguments
  (var i 1)
  (def lenargs (length process/args))
  (while (< i lenargs)
    (def arg (get process/args i))
    (if (and *handleopts* (= "-" (string/slice arg 0 1)))
      (+= i (dohandler (string/slice arg 1 2) i))
      (do
        (set *no-file* false)
        (import* arg :prefix "" :exit *exit-on-error*)
        (set i lenargs))))

  (when (or *should-repl* *no-file*)
    (if-not *quiet*
      (print "Janet " janet/version "-" janet/build "  Copyright (C) 2017-2019 Calvin Rose"))
    (defn noprompt [_] "")
    (defn getprompt [p]
      (def offset (parser/where p))
      (string "janet:" offset ":" (parser/state p) "> "))
    (def prompter (if *quiet* noprompt getprompt))
    (defn getstdin [prompt buf]
      (file/write stdout prompt)
      (file/flush stdout)
      (file/read stdin :line buf))
    (def getter (if *raw-stdin* getstdin getline))
    (defn want-implicit [buf p]
      (and *implicit* (> (length buf) 1) (empty? (parser/state p)) (not= (buf 0) 40)))
    (defn getchunk [buf p]
      (when (getter (prompter p) buf)
        (when (want-implicit buf p)
          (buffer/popn buf 1)
          (let [line (string buf)]
            (buffer/clear buf)
            (buffer/format buf "(%s%s)\n" *implicit* line)))
        buf))
    (def onsig (if *quiet* (fn [x &] x) nil))
    (setdyn :pretty-format (if *colorize* "%.20P" "%.20p"))
    (repl getchunk onsig)))
