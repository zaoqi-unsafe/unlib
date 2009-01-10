#lang scheme/base

(require (for-syntax scheme/base
                     (file "syntax.ss"))
         scheme/provide-syntax
         scheme/string
         (file "base.ss")
         (file "exn.ss"))

; Structure types --------------------------------

; (struct symbol (listof symbol) (listof string))
(define-struct enum (name values pretty-values) #:transparent)

; Accessors and mutators -------------------------

; enum -> string
(define (enum->string enum)
  (string-join (map enum-value->string (enum-values enum)) ", "))

; enum -> string
(define (enum->pretty-string enum)
  (string-join (enum-pretty-values enum) ", "))

; enum any -> boolean
(define (enum-value? enum value)
  (and (memq value (enum-values enum)) #t))

; enum any [(U any (-> any))] -> (U string #f)
(define (enum-prettify
         enum
         value
         [default (cut raise-exn exn:fail:contract
                       (format "expected ~a, received ~a"
                               (enum->string enum)
                               value))])
  (let/ec return
    (for ([val (enum-values enum)]
          [str (enum-pretty-values enum)])
      (when (eq? val value)
        (return str)))
    (if (procedure? default)
        (default)
        default)))

; Syntax -----------------------------------------

; (_ id (value-clause ...) keyword-arg ...)
;
; where 
;     value-clause : id
;                    [id string]
;     keyword-arg  : #:prefix id
;
; Defines an enum: useful wherever you would normally use symbols
; to represent a small set of possible values, but want the compiler to
; warn you if you ever mis-spell them.
; 
; For example (define-enum vehicle car boat plane) binds the following IDs:
;
;     vehicle         : enum     ; (make-enum 'vehicle '(car boat plane) '("car" "boat" "plane"))
;     car             : symbol          ; 'car
;     boat            : symbol          ; 'boat
;     plane           : symbol          ; 'plane
;     vehicle?        : any -> boolean  ; recognizes car, boat and plane (and 'car, 'boat and 'plane)
;     vehicle-out     : provide-form    ; (provide ...) statement that provides all of the above
;
; The optional #:prefix argument can be used to add a prefix to each value ID
; (to produce, for example, vehicle-car, vehicle-boat and vehicle-plane).
(define-syntax (define-enum complete-stx)
  
  ; (U syntax #f)
  (define prefix-stx #f)
  
  ; (listof syntax)
  (define value-id-stxs null)
  
  ; (listof syntax)
  (define value-val-stxs null)
  
  ; (listof syntax)
  (define pretty-stxs null)
  
  ; (listof syntax)
  (define binding-check-stxs null)
  
  ; syntax
  (define predicate-stx #f)
  
  ; syntax -> syntax
  (define (prefix-id id-stx)
    (if prefix-stx
        (make-id id-stx prefix-stx id-stx)
        id-stx))
  
  ; syntax syntax -> void
  (define (parse-values enum-id-stx stx)
    (syntax-case stx ()
      [() (begin (set! value-id-stxs (reverse value-id-stxs))
                 (set! value-val-stxs (reverse value-val-stxs))
                 (set! pretty-stxs (reverse pretty-stxs)))]
      [([id val str] other ...)
       (with-syntax ([enum-id     enum-id-stx]
                     [prefixed-id (prefix-id #'id)])
         (cond [(not (identifier? #'prefixed-id))
                (raise-syntax-error #f "bad enum value" complete-stx #'[id val str])]
               [(identifier-binding #'prefixed-id)
                (set! binding-check-stxs
                      (cons #`(unless (eq? prefixed-id val)
                                (error (format "define-enum ~a: binding discrepancy: ~a is predefined and not eq? to ~a"
                                               'enum-id 'prefixed-id val)))
                            binding-check-stxs))
                (parse-values enum-id-stx #'(other ...))]
               [else (set! value-id-stxs  (cons (prefix-id #'id) value-id-stxs))
                     (set! value-val-stxs (cons #'val value-val-stxs))
                     (set! pretty-stxs    (cons #'str pretty-stxs))
                     (parse-values enum-id-stx #'(other ...))]))]
      [([id str] other ...)
       (with-handlers ([exn? (lambda _ (raise-syntax-error #f "bad enum value" complete-stx #'[id str]))])
         (parse-values enum-id-stx #'([id 'id str] other ...)))]
      [(id other ...)
       (with-handlers ([exn? (lambda _ (raise-syntax-error #f "bad enum value" complete-stx #'id))])
         (with-syntax ([str (datum->syntax enum-id-stx (symbol->string (syntax->datum #'id)))])
           (parse-values enum-id-stx #'([id 'id str] other ...))))]))
  
  ; syntax -> void
  (define (parse-keywords enum-id-stx stx)
    (syntax-case stx ()
      [() (void)]
      [(#:prefix val other ...)
       (identifier? #'val)
       (begin (set! prefix-stx #'val)
              (parse-keywords enum-id-stx #'(other ...)))]
      [(#:predicate val other ...)
       (identifier? #'val)
       (begin (set! predicate-stx #'val)
              (parse-keywords enum-id-stx #'(other ...)))]
      [other (raise-syntax-error #f "bad enum keyword" complete-stx stx)]))
  
  (syntax-case complete-stx ()
    [(_ id (value ...) keyword-arg ...)
     (begin 
       (unless (identifier? #'id) 
         (raise-syntax-error #f "name must be an identifier" complete-stx #'id))
       
       (parse-keywords #'id #'(keyword-arg ...))
       
       (parse-values #'id #'(value ...))
       
       (with-syntax ([enum                #'id]
                     [provide-stmt        (make-id #'id #'id '-out)]
                     [predicate           (or predicate-stx (make-id #'id #'id '?))]
                     [(value-id ...)      value-id-stxs]
                     [(value-val ...)     value-val-stxs]
                     [(pretty ...)        pretty-stxs]
                     [(binding-check ...) binding-check-stxs])
         #'(begin
             ; enum
             (define enum
               (let ([values        (list value-val ...)]
                     [pretty-values (list pretty ...)])
                 (unless (andmap valid-enum-value? values)
                   (raise-exn exn:fail:contract
                     (format "Bad enum values: expected (listof (U boolean symbol integer)), received ~a" values)))
                 (make-enum 'enum values pretty-values)))
             ; (U boolean symbol integer) ...
             (define-values (value-id ...)
               (apply values (enum-values enum)))
             binding-check ...
             ; any -> boolean
             (define predicate
               (cut enum-value? enum <>))
             ; syntax
             (define-provide-syntax provide-stmt
               (lambda (stx)
                 #'(combine-out enum value-id ... predicate))))))]))

; Helpers ----------------------------------------

; any -> boolean
(define (valid-enum-value? val)
  (or (boolean? val)
      (symbol?  val)
      (integer? val)))

; (U boolean symbol integer) -> string
(define (enum-value->string val)
  (cond [(boolean? val) (if val "yes" "no")]
        [(symbol? val)  (symbol->string val)]
        [(integer? val) (number->string val)]))

; Provide statements -----------------------------

(provide define-enum)

(provide/contract
 [struct enum         ([name          symbol?]
                       [values        (listof (or/c boolean? symbol? integer?))]
                       [pretty-values (listof string?)])]
 [enum->string        (-> enum? string?)]
 [enum->pretty-string (-> enum? string?)]
 [enum-value?         (-> enum? any/c boolean?)]
 [enum-prettify       (->* (enum? any/c) ((or/c string? (-> string?))) string?)])