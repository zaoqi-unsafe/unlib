#lang scribble/doc

@(require (file "base.ss"))

@title{@bold{Unlib:} Helpful Utilities from Untyped}

Dave Gurnell, Noel Welsh, David Brooks and Matt Jadud

@tt{{dave, noel, matt} at @link["http://www.untyped.com"]{@tt{untyped}}}

@italic{Unlib} is a collection of general utilities for programming applications in PLT Scheme.
At Untyped we mostly write web software, so expect to find useful utilities for that kind of thing.

Unlib contains a few more modules than listed here. There are several experimental libraries that we developed in the past that have been superseded or partially retired. Expect anything not documented here to change or disappear in the future.

@include-section{bytes.scrbl}
@include-section{cache.scrbl}
@include-section{contract.scrbl}
@include-section{debug.scrbl}
@include-section{enum.scrbl}
@include-section{exn.scrbl}
@include-section{file.scrbl}
@include-section{generator.scrbl}
@include-section{gen.scrbl}
@include-section{hash.scrbl}
@include-section{hash-table.scrbl}
@include-section{keyword.scrbl}
@include-section{log.scrbl}
@include-section{list.scrbl}
@include-section{match.scrbl}
@include-section{number.scrbl}
@include-section{parameter.scrbl}
@include-section{pipeline.scrbl}
@include-section{profile.scrbl}
@include-section{scribble.scrbl}
@include-section{string.scrbl}
@include-section{symbol.scrbl}
@include-section{syntax.scrbl}
@include-section{time.scrbl}
@include-section{url.scrbl}
@include-section{yield.scrbl}