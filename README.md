[![DOI](https://zenodo.org/badge/doi/10.5281/zenodo.8124279.svg)](https://zenodo.org/badge/doi/10.5281/zenodo.8124279.svg)

# cql-parser-xqm

This software package provides an XQuery module developed at the Digital Academy of the Academy of Sciences and Literature | Mainz that may be used to parse [OASIS-CQL](http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/part5-cql/searchRetrieve-v1.0-os-part5-cql.html) and transform any CQL query into XCQL.


# Requirements
The module was developed and tested to be used with the versions 3.1 of XQuery.

The module depends on the following functx functions:

- http://www.xqueryfunctions.com/xq/functx_number-of-matches.html
- http://www.xqueryfunctions.com/xq/functx_get-matches-and-non-matches.html


# How to Use
1. Import the module into your own XQuery script or module in the usual way:

```xquery
import module namespace oasis-cql-parser="http://mwb.adwmainz.net/exist/fcs/oasis-cql-parser" at "PATH/TO/oasis-cql-parser.xqm";
```

2. Use one of the following functions:

## oasis-cql-parser:parse

```xquery
oasis-cql-parser:parse($query as xs:string?) as element()?
```

transforms an OASIS CQL query into an xcql:triple or xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for their schema)

### Parameters:

**$query?** a query following the syntax of OASIS CQL (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/part5-cql/searchRetrieve-v1.0-os-part5-cql.html)

## oasis-cql-parser:parse-simple-query

```xquery
oasis-cql-parser:parse-simple-query($query as xs:string?) as element()?
```

implements level 0 of OASIS CQL by transforming a simple query (with or without quotes) into an xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)

### Parameters:

**$query?** a simple OASIS CQL query e.g. `cat` or `"cat"`

### Returns:

**element()?** the XCQL equivalent - e.g.

```xml
<searchClause xmlns="http://www.loc.gov/zing/cql/xcql/">
    <index>cql.serverChoice</index>
    <relation>=</relation>
    <term>cat</term>
</searchClause>
```


## oasis-cql-parser:parse-relation-query

```xquery
oasis-cql-parser:parse-relation-query($query as xs:string?) as element()?
```

implements level 1 of OASIS CQL by transforming a query with a(n implicit) relation into into an xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)

### Parameters:

**$query?** a simple OASIS CQL query e.g. `cat` or one with a relation e.g. `dc.title any "fish frog"`

### Returns:

**element()?** the XCQL equivalent - e.g.

```xml
<searchClause xmlns="http://www.loc.gov/zing/cql/xcql/">
    <index>cql.serverChoice</index>
    <relation>=</relation>
    <term>cat</term>
</searchClause>
```
or
```xml
<searchClause xmlns="http://www.loc.gov/zing/cql/xcql/">
    <index>c.title</index>
    <relation>any</relation>
    <term>fish frog</term>
</searchClause>
```

## oasis-cql-parser:parse-boolean-query

```xquery
oasis-cql-parser:parse-boolean-query($query as xs:string?) as element()?
```

implements level 1 of OASIS CQL by transforming a query with a(n implicit) relation into an xcql:searchClause element and ones with a boolean into an xcql:triple element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for their schema)

### Parameters:

**$query?** a simple OASIS CQL query e.g. `cat` or one with a relation e.g. `dc.title any "fish frog"` or one with a boolean e.g. `cat or dog`

### Returns:

**element()?** the XCQL equivalent - e.g.

```xml
<searchClause xmlns="http://www.loc.gov/zing/cql/xcql/">
    <index>cql.serverChoice</index>
    <relation>=</relation>
    <term>cat</term>
</searchClause>
```
or
```xml
<searchClause xmlns="http://www.loc.gov/zing/cql/xcql/">
    <index>c.title</index>
    <relation>any</relation>
    <term>fish frog</term>
</searchClause>
```
or
```xml
<triple xmlns="http://www.loc.gov/zing/cql/xcql/">
    <Boolean>
        <value>or</value>
    </Boolean>
    <leftOperand>
        <searchClause>
            <index>cql.serverChoice</index>
            <relation>=</relation>
            <term>cat</term>
        </searchClause>
    </leftOperand>
    <rightOperand>
        <searchClause>
            <index>cql.serverChoice</index>
            <relation>=</relation>
            <term>dog</term>
        </searchClause>
    </rightOperand>
</triple>
```

## oasis-cql-parser:parse-prefixes

```xquery
oasis-cql-parser:parse-prefixes($query as xs:string?) as element()?
```

implements level 2 of OASIS CQL by transforming prefix assignments from a query into an xcql:prefixes element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)

### Parameters:

**$query?** an OASIS CQL query with or without prefix assignments e.g. `> dc = "info:srw/context-sets/1/dc-v1.1" dc.title > cat` or `dog`

### Returns:

**element()?** the XCQL equivalent - e.g.

```xml
<prefixes xmlns="http://www.loc.gov/zing/cql/xcql/">
    <prefix>
        <name>dc</name>
        <identifier>info:srw/context-sets/1/dc-v1.1</identifier>
    </prefix>
</prefixes>
```
or `()`


## oasis-cql-parser:parse-sort-keys

```xquery
oasis-cql-parser:parse-sort-keys($query as xs:string?) as element()?
```

implements level 2 of OASIS CQL by transforming sortBy clauses from a query into an xcql:sortKeys element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)

### Parameters:

**$query?** an OASIS CQL query with or without prefix assignments e.g. `cat sortBy dc.title` or `dog`

### Returns:

**element()?** the XCQL equivalent - e.g.

```xml
<sortKeys xmlns="http://www.loc.gov/zing/cql/xcql/">
    <key>
        <index>dc.title</index>
    </key>
</sortKeys>
```
or `()`

## oasis-cql-parser:remove-prefix-assignments

```xquery
oasis-cql-parser:remove-prefix-assignments($query as xs:string?) as xs:string?
```

removes prefix assignments from a OASIS CQL query

### Parameters:

**$query?** an OASIS CQL query with or without prefix assignments e.g. `> dc = "info:srw/context-sets/1/dc-v1.1" dc.title > cat` or `dog`

### Returns:

**xs:string?** the query without prefix assignments e.g. `dc.title > cat` or `dog`

## oasis-cql-parser:remove-sortby

```xquery
oasis-cql-parser:remove-sortby($query as xs:string) as xs:string?
```

removes sortBy clauses from a OASIS CQL query

### Parameters:

**$query?** an OASIS CQL query with or without sortBy clauses e.g. `dinosaur sortBy dc.date/sort.descending dc.title/sort.ascending` or `dog`

### Returns:

**xs:string?** the query without prefix assignments e.g. `dinosaur` or `dog`

---

# License
The software is published under the terms of the MIT license.


# Research Software Engineering and Development

Copyright 2023 <a href="https://orcid.org/0000-0002-5843-7577">Patrick Daniel Brookshire</a>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
