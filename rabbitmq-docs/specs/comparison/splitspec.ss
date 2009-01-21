(require xml)
(require srfi/13)

(define args (current-command-line-arguments))

(when (< (vector-length args) 1)
  (display "Usage: splitspec <dirname>")
  (newline)
  (exit))

(define dir (vector-ref args 0))

(make-directory dir)

(define doc (xml->xexpr (document-element (read-xml))))

(define (normalize-amqp-name name)
  (string-downcase
   (string-filter (lambda (c)
		    (case c
		      ((#\space #\-) #f)
		      (else #t)))
		  name)))

(define (normalize-amqp-attribute-entry entry)
  (string-append "_" (normalize-amqp-name (cadr entry))))

(define xname car)
(define (xattr n)
  (if (and (pair? (cdr n))
	   (pair? (cadr n))
	   (pair? (caadr n)))
      (cadr n)
      '()))
(define (xchildren n)
  (cond
   ((null? (cdr n)) '())
   ((null? (cadr n)) (cddr n))
   ((pair? (cadr n))
    (if (pair? (caadr n))
	(cddr n)
	(cdr n)))
   (else (cdr n))))

(define (tweak-leaf n)
  (cond
   ((string? n) (string-trim-both n))
   (else
    `(,(xname n) ()
      ,@(let ((a (xattr n)))
	  (if (null? a)
	      '()
	      `((attributes () ,@(xattr n)))))
      ,@(append-map (lambda (child)
		      (cond
		       ((string? child) (list (string-trim-both child)))
		       (else (list (tweak-leaf child)))))
		    (xchildren n))))))

(define (dump-leaf dir-prefixes-reversed filename child)
  (let ((p (apply build-path (reverse (cons filename dir-prefixes-reversed)))))
    (with-output-to-file p
      (lambda ()
	;;(pretty-print (tweak-leaf child))
	(display-xml/content (xexpr->xml (tweak-leaf child)))
	)
      #:exists 'append)))

(define (dump-node dir-prefixes-reversed node)
  (define (dump-child child)
    (cond
     ((string? child)
      ;;(dump-leaf dir-prefixes-reversed "__pcdata__" child)
      )
     (else
      (let* ((name (cond
		    ((assq 'name (xattr child)) => normalize-amqp-attribute-entry)
		    ((assq 'type (xattr child)) => normalize-amqp-attribute-entry)
		    (else "")))
	     (filename (string-append (symbol->string (xname child)) name)))
	(case (xname child)
	  ((class method)
	   (let ((p (cons filename dir-prefixes-reversed)))
	     (make-directory (apply build-path (reverse p)))
	     (dump-leaf p "__attributes__" `(,(xname child) ()
					     (pcdata ,@(filter string? (xchildren child)))
					     ,@(xattr child)))
	     (dump-node p child)))
	  (else
	   (dump-leaf dir-prefixes-reversed filename child)))))))
  (for-each dump-child (xchildren node)))

(dump-node (list dir) doc)
