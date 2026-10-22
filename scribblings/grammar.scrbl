#lang scribble/manual
@(require racket/file racket/runtime-path "site-head.rkt" "site-links.rkt")
@(define-runtime-path grammar-path "../spec/compact.ebnf")

@title[#:style (page-style) #:tag "compact-grammar"]{Compact grammar}

This page collects the current compact syntax in one reference. The grammar
and the rules below must be read together: the brackets alone cannot decide
which names are visible, whether a path can be updated, or whether a call
has the right inputs. These rules describe the language's written forms.
They do not define scientific adequacy or require scientific assessment
applications to be written in Racket.

The @hyperlink[(source-file-url "spec/compact.ebnf")]{standalone grammar file}
is included verbatim below. The explanations linked from @secref["reference"]
define the meaning of each form. @secref["verbose-syntax"] describes the
normalization of verbose and mixed spellings to this compact grammar.

@section{Grammar notation}

In the grammar, @tt{=} defines a rule, a comma joins parts, @tt{|} offers
alternatives, @tt{[ ... ]} makes something optional, and @tt["{ ... }"] repeats
it zero or more times. Quoted punctuation is literal ScienceLogo punctuation.
For example, @tt{"["} is a source bracket; an unquoted bracket belongs to
the grammar notation. A description between question marks supplies a
character or contextual condition. These rules are independent of a parser
generator. The expression rules additionally use the binding procedure below.

@verbatim[(file->string grammar-path)]

@section{Tokens, text, and names}

After the first @tt{#lang sciencelogo} line, whitespace and comments separate
tokens. Newlines do not end commands. Brackets, parentheses, and quoted text
separate themselves from adjacent words. Other punctuation stays inside a
word: write @tt{x = 2}, not @tt{x=2}, and @tt{1 + 2}, not @tt{1+2}.
A dot stays attached to the following path part, as in @tt{trial.period} or
@tt{trial.[1]}; it is not an arithmetic operator. To apply a suffix directly
to a numeric literal, group it, for example @tt{(2 u []).u}, rather than
merging the literal and path into one word.
The grammar's reference, input, and path rules describe those word parts;
they do not require the lexer to emit separate dot or colon tokens.
A qualified procedure or interface reference is one word. A value path can
continue in a following word that starts with a dot: @tt{trial .period}
works, while @tt{trial . period} does not.

Numbers use an optional sign, decimal digits, and an optional fractional
part with digits on both sides of its dot. They are exact. Exponent notation,
a leading decimal point, and a fraction such as @tt{1/3} are not numeric
literals. Division can produce an exact fraction. A sign attached to digits
is part of the literal; a separate @tt{-} is unary subtraction.

Quoted text may span lines. Escapes include quotes and backslash,
@tt{\a}, @tt{\b}, @tt{\t}, @tt{\n}, @tt{\v}, @tt{\f}, @tt{\r}, and @tt{\e};
their character codes are respectively 7, 8, 9, 10, 11, 12, 13, and 27.
Numeric and escaped-line-ending forms are listed in the grammar. An escaped
line ending contributes no character. Other backslash escapes are invalid.

@secref["reference"] gives the naming conventions. Names are case-sensitive;
letter case is guidance. Names in declarations and references are unquoted
identifiers. This includes stage, interface, and library names. Quoted text
is a string value; it cannot name or reference one of those declarations.
Stage, interface, and library declaration names have no dots and do not begin
with a number. A dot
separates nested parts; a colon marks a procedure input and is used only
inside that procedure. Input declarations and references keep the colon
attached to their name. The reader treats kind labels such as @tt{number}
as ordinary names except in a type position. The words @tt{stages} and
@tt{order} likewise have meaning in @tt{must stages in order} without being
reserved everywhere.

These words and operators are reserved as ordinary names:

@verbatim|{
to do stage end print output include implements must workflow interface about
performer resource hypothesis assumption conclusion repeat for while if else
set as at from with into state import library version require affects provide
by each in until range step true false unknown = == += != < <= > >=
+ - * / and or not xor of but implement is extends
hypotheses assumptions conclusions u
}|

The plural proposition words are nevertheless valid collection roots and
record keys. Reserved @tt{set}, @tt{require}, @tt{of}, and @tt{but} have no
accepted compact command or operator form. Reserving a word does not
implement a feature. @tt{about} is accepted only at the description attachment
points explained in @secref["descriptions"].

@section{Expression binding}

Read expressions with the following priorities, from strongest to weakest:

@(tabular #:style 'boxed
  (list
   (list (bold "Priority") (bold "Forms"))
   (list "Postfix" (tt ".field, .[...], u [...]"))
   (list "70" (tt "unary -"))
   (list "60" (tt "* /"))
   (list "50" (tt "+ -"))
   (list "40" (tt "== != < <= > >= in is; operand of not"))
   (list "30" (tt "and"))
   (list "20" (tt "xor"))
   (list "10" (tt "or"))))

To read an expression with minimum priority @tt{p}, first read an operand.
A prefix @tt{-} reads its operand with minimum 70; @tt{not} reads its
operand with minimum 40. An ordinary primary then consumes its postfix
suffixes. While the next operator has priority at least @tt{p}, consume it
and read its right operand with minimum one greater than that priority.
For @tt{is}, consume one type reference instead of a right expression.
The result becomes the left operand for the next operator. A full expression
starts with minimum 0, and parentheses start a fresh full expression.
This procedure gives left association within a priority and makes
@tt{not period > 2} mean @tt{not (period > 2)}.

Unparenthesized comparison chains such as @tt{1 < 2 < 3} are rejected;
use @tt{1 < 2 and 2 < 3} for those two conditions. A grouped comparison is
a value: @tt{(1 == 1) == true} and @tt{(2 is number) == true} are valid.
Every explicit pair of parentheses is retained in the parsed tree and
workflow model, including extra groups such as @tt{(((1 == 1)))}.
Checks and evaluation follow that grouping. Parentheses are available
wherever the grammar accepts a value expression.

Range bounds and the step are full expressions: @tt{to} and @tt{step} stop
the preceding bound. Parenthesize the range before applying a suffix to
the whole list, as in @tt{(range 1 to 3 step 1).count}. Similarly,
@tt{(duration / swings) u [...]} attaches the description to the quotient.

@section{Choosing between bracket forms}

At the start of a bracketed value, a word followed immediately by an
@tt{=} token selects a record. Otherwise the brackets contain list items.
Thus @tt{[period = 2]} is a record, @tt{[period 2]} is a list, and
@tt{[]} is an empty list. Dotted field keys expand into nested records.
Repeated or conflicting field paths are invalid. In an object position
such as a performer declaration, @tt{[]} denotes an empty object.

After a dot, named fields select a record update or a construction from an
interface; @tt{[]} is the empty update. Other nonempty brackets select
fields or one-based list positions. A record selection uses bare field
labels; a list selection uses index expressions. A single selection returns
the field or item value. Several selected record fields return a record;
several selected list positions return a list.
An expression such as @tt{copy = trial.[period = 2]} produces a
value. The command @tt{trial.[period = 2]} updates an existing writable name.
See @secref["values"].

The @tt{in} operator has one contextual distinction: a list receiver uses
the left operand's value, while a record receiver requires a bare unquoted
field label on the left. The label identifies one immediate key, regardless
of its value. It does not need a variable declaration. A nested receiver
such as @tt{notes in trial.details} inspects that nested record.

The grammar describes assignment targets using paths. A target must also
resolve to a writable name or location. A selector used for assignment must
identify one existing list position or one field; a record update may add
fields. The list property @tt{.count} is read only. An ordinary record's
@tt{count} field remains writable. @tt{.u} addresses an attached uncertainty
description, which must retain the shape defined in @secref["uncertainty"].

@section{Command boundaries and placement}

The file's role determines which declarations are allowed. A workflow title
is optional and appears only first. A workflow's optional @tt{about} follows
that title and precedes imports. Workflow imports precede other forms.
Library imports belong directly in the root library
block. Included workflow fragments have no title or imports; included library
fragments contain only procedures, interfaces, and further includes.
A file beginning with an interface and continuing with other forms is a
workflow with an inline interface. A file containing only that declaration
is a standalone interface.

A procedure's optional @tt{about} is first inside its opening bracket.
A stage's optional @tt{about} immediately follows its complete header,
including entry state for a paired stage. Each attachment accepts one quoted
string. These descriptions are not commands in anonymous blocks and do not
affect execution or checks; see @secref["descriptions"].

Procedure definitions, interfaces, performers, resources, proposition
declarations, obligations, and the older file-provision form belong at
workflow top level. Libraries contain only the declarations listed in
@tt{library-form}. A command block cannot define procedures or interfaces.
The @tt{output} command belongs inside a procedure; it returns immediately.
See @secref["procedures"] for value scope, protected names, and updates.

For an ordinary @tt{do name ...} call, keep reading argument expressions
until @tt{as}, a closing bracket, end of file, a command-start word, or a
recognized assignment or dotted-update start. A newline is not a
boundary, and the procedure's input count does not stop parsing arguments.
The reader checks that count afterwards. The command-start words are:

@verbatim|{
to do stage end print output include implements must workflow interface
performer resource hypothesis assumption conclusion repeat for while if else set about
}|

Because proposition declaration words end an argument list, enclose a new
proposition value in parentheses when passing it directly as an argument.

An assignment start here is a word immediately followed by @tt{=} or
@tt{+=}. A dotted-update start is a word ending in a dot followed by
@tt{[}, a field word, and @tt{=}. These tests do not recognize every possible
path command: for example, an indexed assignment or an empty dotted update
after a call needs an explicit call boundary.

A mapping beginning with a stage, procedure, or value name does not itself
end an argument list. An @tt{as} result gives an explicit boundary; a mapping
can also be separated by placing the call in @tt{do [...]}. After a call's
@tt{as name}, the next form starts normally. Expressions greedily consume
operators: in @tt{do pair 1 - 2}, the call receives one subtraction
expression. Use @tt{do pair 1 (- 2)} for two arguments.

@section{Stage, data, and proposition constraints}

A paired stage must supply both boundary state objects, even when empty.
Its state sets are individually optional, but each present set contains
named fields or @tt{[]}. Stages cannot nest inside a paired stage.
Location calls are allowed only there; an ordinary value-argument call is
not allowed in a paired stage. The location grammar does not permit
multi-field projections or update objects. Its field parts cannot be
reserved words.

Every location call maps each declared input exactly once and names a
compulsory return location. A declared performer comes from the call or
stage. Input paths must exist and return paths must have an existing
parent; list positions must already exist. Local stage names describe
integer counters and positions. Changes must account for the full closing
state. These restrictions and the rules for branches and loops are detailed
in @secref["stages"]. Stage handoff is available without being compulsory.
Paired bodies are preserved and checked, not executed.

All access to data outside the workflow uses a declared @tt{resource}
root and an ordinary dotted path. Assignment direction represents reading
or writing. A resource declaration's descriptive fields are not the data
at those locations. Source dependencies use their own paths.
See @secref["resources"].

A proposition must have a @tt{text} field that evaluates to text, and it
may have named child collections. Omitted collections
are empty. Names are unique within their type and parent. Adding a named
child with @tt{+=} rejects a duplicate; @tt{=} updates fields without
creating a new proposition or changing its identity. The language does
not require a conclusion for every hypothesis. See @secref["propositions"].

@section{Interface disambiguation and constraints}

Inside @tt{must [...]}, first read a candidate expression. A comparison,
@tt{is} test, arithmetic or Boolean expression, unary expression, or literal
is a value requirement. Otherwise read a field declaration or named group.
A bare field must be written as a word, not a parenthesized expression.
The group must contain at least one entry. Outside @tt{must}, a bare field,
@tt{field is Type}, or named group is optional. A default makes its field
compulsory even outside @tt{must}; examples group defaults inside it.

The optional type suffix is allowed only after an explicit @tt{unknown}
default, including one with @tt{u}. A primitive kind is recognized there
immediately. A named interface reference is recognized after imports and
includes are assembled, using the declarations rather than letter case.
It consumes only an immediately adjacent bare entry in the same group.
A following entry with its own @tt{=} or @tt{is} remains separate.
A word that names no interface remains a separate field. Separate
@tt{must} groups disambiguate a field with the same name as an interface.
See @secref["interfaces"].

An interface has a nonempty name and at most one nonempty version. It
needs a field, parent, or value requirement. Only the root can use
@tt{version} and @tt{extends}. Field paths are unique within their parent,
including across branches. Parents must resolve without cycles or
unresolved conflicts. A standalone interface cannot extend a local
interface. @tt{affects} links compulsory parts. Per-item names are local
to their requirement blocks. Named type targets must resolve to an
interface or nested group. See @secref["interfaces"].

Mapping targets may name an entire interface or an individual requirement.
A stage mapping uses its declared, unquoted name, including a forward or
imported qualified reference. Ambiguous targets that also identify another
visible value or definition are rejected. A source-file mapping target is
available for a value, not a stage or procedure. Mappings preserve the
stated relationship; they do not establish scientific conformity.
See @secref["assessment"].

@section{Resolution and implementation boundaries}

All procedure, stage, interface, performer, and resource references must
resolve. Declarations may follow their uses; local values must already be
visible. Calls have the declared input count, requested results need an
output, and recursive procedure calls are rejected. Stage names are
unique across the workflow and its procedures. Procedure names are also
unique; the naming rules specify conflicts with other namespaces.
Includes must remain in their Git
repository, without repeated files or cycles. Imports choose a tag or full
commit on @tt{main}; dependency aliases remain private. See
@secref["libraries"].

Interface references are resolved from declarations after imports and
includes are assembled. A library interface named @tt{timing_shape} uses
@tt{tools.timing_shape}, including in constructors, named tests, defaults,
and nested requirement mappings. Capitalization and hyphens remain
optional naming conventions. Private dependency aliases remain private
regardless of their spelling.

A grammar match is only the first check. Name resolution, placement,
writability, and the stated structural constraints are also required.
Value operations can still fail when run, for example because an index is
out of bounds or division uses zero. Scientific assessments remain
independent applications.
