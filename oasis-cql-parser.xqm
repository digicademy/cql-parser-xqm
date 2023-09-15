xquery version "3.1";

(:
 : MWB | OASIS-CQL parser
 :
 : Edited and developed by Patrick D. Brookshire and Ute Recker-Hamm
 : Academy of Sciences and Literature | Mainz
 :
 : xquery module containing various functions used for parsing OASIS-CQL queries (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/part5-cql/searchRetrieve-v1.0-os-part5-cql.html)
 : and transforming them into their XCQL equivalent (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd)
 :
 : @author Patrick D. Brookshire
 : @licence MIT
:)

module namespace oasis-cql-parser="http://mwb.adwmainz.net/exist/fcs/oasis-cql-parser";

import module namespace functx = "http://www.functx.com";

declare default element namespace "http://www.loc.gov/zing/cql/xcql/";

declare variable $oasis-cql-parser:error-namespace := "http://cql.parser/err";

declare variable $oasis-cql-parser:default-index := "cql.serverChoice";
declare variable $oasis-cql-parser:default-relation := "=";

declare %private variable $oasis-cql-parser:simple-unquoted-query-pattern := '^([^ ]+?)$';
declare %private variable $oasis-cql-parser:simple-quoted-query-pattern := '^"([^ ]+?)"$';
declare %private variable $oasis-cql-parser:simple-relation-query-pattern := '^([^ =<>"]+?) *?([=<>]=?|<>) *?(([^ =<>]+?)|"(.+?)")$';
declare %private variable $oasis-cql-parser:relation-query-pattern := '^([^ =<>"]+?) +?([^ ]+?) +?(([^ =<>]+?)|"(.+?)")$';
declare %private variable $oasis-cql-parser:boolean-query-pattern := '^(.*?)? ([Aa][Nn][Dd](?:/[^/ ]+?)*|[Oo][Rr](?:/[^/ ]+?)*|[Nn][Oo][Tt](?:/[^/ ]+?)*|[Pp][Rr][Oo][Xx](?:/[^/ ]+?)*) (.*)?$';

declare %private variable $oasis-cql-parser:prefix-assignment-pattern := '> +([^ =]+) *= *"(.*?)"';

(: local serialization helper methods :)
declare %private function oasis-cql-parser:unquote-term($term as xs:string?) as xs:string? {
    replace(replace($term, '^"(.*?)"$', "$1"), '\\"', '"')
};

declare %private function oasis-cql-parser:get-modifiers($relation-or-boolean as xs:string) as xs:string* {
    tokenize($relation-or-boolean, "/")[position() ne 1]
};

declare %private function oasis-cql-parser:remove-modifiers($relation-or-boolean as xs:string) as xs:string? {
    tokenize($relation-or-boolean, "/")[1]
};

declare %private function oasis-cql-parser:build-modifiers($relation-or-boolean as xs:string) as element(modifiers)? {
    let $modifiers := oasis-cql-parser:get-modifiers($relation-or-boolean)
    where count($modifiers) gt 0
    return
        <modifiers>
            {
                for $modifier in $modifiers
                return
                    if (matches($modifier, $oasis-cql-parser:simple-relation-query-pattern)) then
                        let $type := replace($modifier, $oasis-cql-parser:simple-relation-query-pattern, "$1")
                        let $comparison := replace($modifier, $oasis-cql-parser:simple-relation-query-pattern, "$2")
                        let $value := replace($modifier, $oasis-cql-parser:simple-relation-query-pattern, "$3")
                        return
                            if (normalize-space($comparison) eq "><") then
                                error(QName($oasis-cql-parser:error-namespace, "CQL-Error"), "Unsupported comparison symbol '" || $comparison || "'")
                            else
                                <modifier>
                                    <type>{ oasis-cql-parser:unquote-term($type) }</type>
                                    <comparison>{ oasis-cql-parser:unquote-term($comparison) }</comparison>
                                    <value>{ oasis-cql-parser:unquote-term($value) }</value>
                                </modifier>
                    else
                        <modifier>
                            <type>{ oasis-cql-parser:unquote-term($modifier) }</type>
                        </modifier>
            }
        </modifiers>
};

declare %private function oasis-cql-parser:build-search-clause($index as xs:string, $relation as xs:string, $term as xs:string) as element(searchClause)? {
    if (normalize-space($relation) eq "><") then
        error(QName($oasis-cql-parser:error-namespace, "CQL-Error"), "Unsupported relation '" || $relation || "'")
    else
        <searchClause>
            <index>{ $index }</index>
            <relation>
                <value>{ oasis-cql-parser:remove-modifiers($relation) }</value>
                { oasis-cql-parser:build-modifiers($relation) }
            </relation>
            <term>{ oasis-cql-parser:unquote-term($term) }</term>
        </searchClause>
};

declare %private function oasis-cql-parser:build-search-clause($term as xs:string) as element(searchClause)? {
    oasis-cql-parser:build-search-clause($oasis-cql-parser:default-index, $oasis-cql-parser:default-relation, $term)
};


(: MAIN PARSER FUNCTIONS :)
(:~ transforms an OASIS CQL query into an xcql:triple or xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for their schema)
 : @param $query a query following the syntax of OASIS CQL (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/part5-cql/searchRetrieve-v1.0-os-part5-cql.html)
 : @error this function may raise an CQL Error if the given query is invalid
:)
declare function oasis-cql-parser:parse($query as xs:string?) as element()? {
    oasis-cql-parser:parse-boolean-query(oasis-cql-parser:remove-prefix-assignments(oasis-cql-parser:remove-sortby($query)))
};

(: Level 0 :)
(:~ implements level 0 of OASIS CQL by transforming a simple query (with or without quotes) into an xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)
 : @param $query a simple OASIS CQL query e.g. `cat` or `"cat"`
 : @error this function may raise an CQL Error if the given query is invalid (e.g. `cat dog` or `cat <> dog`)
:)
declare function oasis-cql-parser:parse-simple-query($query as xs:string?) as element(searchClause)? {
    let $query := normalize-space($query)
    return
        if ($query eq "") then
            oasis-cql-parser:build-search-clause("")
        else if (matches($query, $oasis-cql-parser:simple-unquoted-query-pattern)) then
            oasis-cql-parser:build-search-clause(replace($query, $oasis-cql-parser:simple-unquoted-query-pattern, "$1"))
        else if (matches($query, $oasis-cql-parser:simple-quoted-query-pattern)) then
            oasis-cql-parser:build-search-clause(replace($query, $oasis-cql-parser:simple-quoted-query-pattern, "$1"))
        else
            error(QName($oasis-cql-parser:error-namespace, "CQL-Error"), "Query syntax error")
};

(: Level 1a :)
(:~ implements level 1 of OASIS CQL by transforming a query with a(n implicit) relation into into an xcql:searchClause element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)
 : @param $query a simple OASIS CQL query e.g. `cat` or one with a relation e.g. `dc.title any "fish frog"`
 : @error this function may raise an CQL Error if the given query is invalid (e.g. `cat dog` or `cat >< dog`)
:)
declare function oasis-cql-parser:parse-relation-query($query as xs:string?) as element(searchClause)? {
    if (matches($query, $oasis-cql-parser:simple-relation-query-pattern)) then
        oasis-cql-parser:build-search-clause(replace($query, $oasis-cql-parser:simple-relation-query-pattern, "$1"), replace($query, $oasis-cql-parser:simple-relation-query-pattern, "$2"), replace($query, $oasis-cql-parser:simple-relation-query-pattern, "$3"))
    else if (matches($query, $oasis-cql-parser:relation-query-pattern)) then
        oasis-cql-parser:build-search-clause(replace($query, $oasis-cql-parser:relation-query-pattern, "$1"), replace($query, $oasis-cql-parser:relation-query-pattern, "$2"), replace($query, $oasis-cql-parser:relation-query-pattern, "$3"))
    else 
        oasis-cql-parser:parse-simple-query($query)
};

(: Level 1b :)
declare %private function oasis-cql-parser:get-substring-until-closing-bracket($query) {
    oasis-cql-parser:get-substring-until-closing-bracket($query, 1)
};

declare %private function oasis-cql-parser:get-substring-until-closing-bracket($query, $i) {
    if (($i lt 1) or ($i gt string-length($query))) then
        () (: $i is invalid or there are more intermediary opening brackets than closing ones :)
    else
        let $substring := substring($query, 1, $i)
        let $quot-count := functx:number-of-matches($substring, '[^\\]"') + functx:number-of-matches($substring, '""')
        let $sum := 
            if ($quot-count mod 2 eq 1) then (: ignore substrings with an odd number of quotation marks because that means that a quoted part is ot yet unquoted :)
                0
            else
                sum(
                    let $unquoted-substring := string-join(functx:get-matches-and-non-matches($substring, '".*?[^\\]"')[name() eq "non-match"])
                    for $codepoint in string-to-codepoints($unquoted-substring) (: ignore quoted parts while comparing the number of opening and closing brackets :)
                    return
                        if ($codepoint eq 40) then (: eq "(" :)
                            1
                        else if ($codepoint eq 41) then (: eq ")" :)
                            -1
                        else
                            0
        )
        return
            if ($sum eq -1) then (:  the number of intermediary opening brackets equals the number of closing brackets :)
                $substring
            else
                oasis-cql-parser:get-substring-until-closing-bracket($query, $i + 1)
};

(:~ implements level 1 of OASIS CQL by transforming a query with a(n implicit) relation into an xcql:searchClause element and ones with a boolean into an xcql:triple element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for their schema)
 : @param $query a simple OASIS CQL query e.g. `cat` or one with a relation e.g. `dc.title any "fish frog"` or one with a boolean e.g. `cat or dog`
 : @error this function may raise an CQL Error if the given query is invalid (e.g. `cat dog` or `cat >< dog` or `NOT dog`)
:)
declare function oasis-cql-parser:parse-boolean-query($query as xs:string?) as element()? {
    if (matches($query, $oasis-cql-parser:boolean-query-pattern)) then
        let $left-operand := replace($query, $oasis-cql-parser:boolean-query-pattern, "$1")
        let $boolean-with-modifiers := replace($query, $oasis-cql-parser:boolean-query-pattern, "$2")
        let $right-operand := replace($query, $oasis-cql-parser:boolean-query-pattern, "$3")
        return
            (: handle complex left operand :)
            if (starts-with($left-operand, "(")) then
                let $left-operand := oasis-cql-parser:get-substring-until-closing-bracket(substring($query, 2)) (: remove leading "(" :)
                let $left-operand := substring($left-operand, 1, string-length($left-operand) - 1) (: remove trailing ")" :)
                let $right-subquery := substring($query, string-length($left-operand) + 2)
                return
                    if (matches($right-subquery, $oasis-cql-parser:boolean-query-pattern)) then
                        let $boolean-with-modifiers := replace($right-subquery, $oasis-cql-parser:boolean-query-pattern, "$2")
                        let $right-operand := replace($right-subquery, $oasis-cql-parser:boolean-query-pattern, "$3")
                        return
                            <triple>
                                <Boolean>
                                    <value>{ lower-case(oasis-cql-parser:remove-modifiers($boolean-with-modifiers)) }</value>
                                    { oasis-cql-parser:build-modifiers($boolean-with-modifiers) }
                                </Boolean>
                                <leftOperand>{ oasis-cql-parser:parse-boolean-query($left-operand) }</leftOperand>
                                <rightOperand>{ oasis-cql-parser:parse-boolean-query($right-operand) }</rightOperand>
                            </triple>
                    else
                        oasis-cql-parser:parse-boolean-query($left-operand)
            else
                <triple>
                    <Boolean>
                        <value>{ lower-case(oasis-cql-parser:remove-modifiers($boolean-with-modifiers)) }</value>
                        { oasis-cql-parser:build-modifiers($boolean-with-modifiers) }
                    </Boolean>
                    <leftOperand>{ oasis-cql-parser:parse-boolean-query($left-operand) }</leftOperand>
                    <rightOperand>{ oasis-cql-parser:parse-boolean-query($right-operand) }</rightOperand>
                </triple>
    else 
        oasis-cql-parser:parse-relation-query($query)
};

(: Level 2 :)
(:~ implements level 2 of OASIS CQL by transforming prefix assignments from a query into an xcql:prefixes element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)
 : @param $query an OASIS CQL query with or without prefix assignments e.g. `> dc = "info:srw/context-sets/1/dc-v1.1" dc.title > cat` or `dog`
:)
declare function oasis-cql-parser:parse-prefixes($query as xs:string?) as element(prefixes)? {
    let $prefixes := 
        for $prefix-assignment in functx:get-matches-and-non-matches($query, $oasis-cql-parser:prefix-assignment-pattern)[name() eq "match"]
        let $prefix := replace($prefix-assignment, $oasis-cql-parser:prefix-assignment-pattern, "$1")
        let $uri := replace($prefix-assignment, $oasis-cql-parser:prefix-assignment-pattern, "$2")
        group by $prefix
        return
            <prefix>
                <name>{ $prefix }</name>
                <identifier>{ $uri[last()] }</identifier>
            </prefix>
    where count($prefixes) gt 0
    return
        <prefixes>
            { $prefixes }
        </prefixes>
};

(:~ removes prefix assignments from a OASIS CQL query
 : @param $query an OASIS CQL query with or without prefix assignments e.g. `> dc = "info:srw/context-sets/1/dc-v1.1" dc.title > cat` or `dog`
 : @return the query without prefix assignments e.g. `dc.title > cat` or `dog`
:)
declare function oasis-cql-parser:remove-prefix-assignments($query as xs:string?) as xs:string? {
    replace($query, "^( *" || $oasis-cql-parser:prefix-assignment-pattern || " *)+", "")
};

(:~ implements level 2 of OASIS CQL by transforming sortBy clauses from a query into an xcql:sortKeys element (c.f. http://docs.oasis-open.org/search-ws/searchRetrieve/v1.0/os/schemas/xcql.xsd for its schema)
 : @param $query an OASIS CQL query with or without prefix assignments e.g. `cat sortBy dc.title` or `dog`
:)
declare function oasis-cql-parser:parse-sort-keys($query as xs:string?) as element(sortKeys)? {
    let $sortby-clauses := tokenize(tokenize($query, "[Ss][Oo][Rr][Tt][Bb][Yy]")[2], " +")[. ne ""]
    where count($sortby-clauses) gt 0
    return
        <sortKeys>
            {
                for $sortby-clause in $sortby-clauses
                return
                    <key>
                        <index>{ oasis-cql-parser:remove-modifiers($sortby-clause) }</index>
                        { oasis-cql-parser:build-modifiers($sortby-clause) }
                    </key>
            }
        </sortKeys>
};

(:~ removes sortBy clauses from a OASIS CQL query
 : @param $query an OASIS CQL query with or without sortBy clauses e.g. `dinosaur sortBy dc.date/sort.descending dc.title/sort.ascending` or `dog`
 : @return the query without prefix assignments e.g. `dinosaur` or `dog`
:)
declare function oasis-cql-parser:remove-sortby($query as xs:string) as xs:string? {
    tokenize($query, "[Ss][Oo][Rr][Tt][Bb][Yy]")[1]
};

