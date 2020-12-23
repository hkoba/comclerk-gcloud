#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ComDict {
    variable myGlobalOptions
    
    variable myPrefixDict [dict create]
    
    method accept {command args} {
        # puts [list gcloud {*}$args]
        set globalOpts [$self take-global-options args]
        if {[set prefix [$self match-prefix $args]] eq ""} {
            return
        }
        set matched [dict get $myPrefixDict $prefix]
        set rest [lrange $args [llength $prefix] end]
        dict with matched {
            set customOpts \
                [lassign [$self $kind take-name-arg rest $matched] name]
            dict create \
                command $command \
                verb $trigger_verb resource $resource \
                kind $kind \
                name $name prefix $prefix options $rest \
                {*}$customOpts \
                {*}$globalOpts
        }
    }

    method stringify accepted {
        append cmd "[dict get $accepted command] --[dict get $accepted project] [dict get $accepted prefix] [$self dispatch $accepted name-arg] \\\n"
        if {[set opts [dict get $accepted options]] ne ""} {
            append cmd "  [join $opts " \\\n  "]\n"
        }
        append cmd "\n"
    }

    method install script {
        apply [list self $script] $self
        set self
    }

    method define {prefixKind resource args} {
        set item [$self $prefixKind define \
                      [dict create \
                           kind $prefixKind \
                           resource $resource] {*}$args]
        if {$item eq ""} {
            # configure で追加まで行なう
        } else {
            set prefix [dict get $item verbs [dict get $item trigger_verb]]
            if {[dict exists $myPrefixDict $prefix]} {
                error "Command definition confliction: gcloud $prefix"
            }
            dict set myPrefixDict $prefix $item
        }
    }

    method dispatch {specDict meth args} {
        set kind [dict get $specDict kind]
        $self $kind $meth $specDict {*}$args
    }

    method match-prefix argList {
        foreach prefix [dict keys $myPrefixDict] {
            if {[lrange $argList 0 [expr {[llength $prefix]-1}]] eq $prefix} {
                return $prefix
            }
        }
    }

    method take-global-options varName {
        upvar 1 $varName argVar
        set tobeRemoved []
        set pos 0
        foreach arg $argVar {
            if {[regexp {^--(\w+)=(.*)} $arg -> name value]} {
                if {[dict exists $myGlobalOptions $name]} {
                    lappend tobeRemoved [list $pos $name $value]
                }
            }
            incr pos
        }
        
        set removedOpts [dict create]
        foreach item [lreverse $tobeRemoved] {
            lassign $item pos name value
            dict set removedOpts $name $value
            set argVar [lreplace $argVar $pos $pos]
        }
        set removedOpts
    }

    method define-global-option option {
        # XXX: 重複検査
        dict set myGlobalOptions $option [dict create]
    }

    method {1arg-prefix define} {item action prefix args} {
        dict merge $item \
            [dict create \
                 trigger_verb $action \
                 verbs [dict create $action $prefix {*}$args]]
    }

    method {1arg-prefix take-name-arg} {argListVar specDict} {
        upvar 1 $argListVar argList
        set argList [lassign $argList name]
        list $name
    }

    method {1arg-prefix name-arg} {specDict} {
        dict get $specDict name
    }

    method {named-arg-prefix define} {item action nameArg prefix args} {
        dict merge $item \
            [dict create \
                 trigger_verb $action \
                 nameArg $nameArg \
                 verbs [dict create $action $prefix {*}$args]]
    }
    
    method {named-arg-prefix take-name-arg} {argListVar specDict} {
        upvar 1 $argListVar argList
        set nameArg [dict get $specDict nameArg]
        if {[set pos [$self lsearch-option $argList $nameArg value]] >= 0} {
            set argList [lreplace $argList $pos $pos]
            return [list $value nameArg $nameArg]
        }
    }
    
    method {named-arg-prefix name-arg} {specDict} {
        set nameArg [dict get $specDict nameArg]
        set name [dict get $specDict name]
        return --$nameArg=$name
    }

    method lsearch-option {argList name {valueVar ""}} {
        if {$valueVar ne ""} {
            upvar 1 $valueVar value
        }
        for {set i 0} {$i < [llength $argList]} {incr i} {
            set arg [lindex $argList $i]
            if {[regexp {^--(\w+)(?:=(.*))?} $arg -> nm val]
                && $nm eq $name} {
                set value $val
                return $i
            }
        }
        return -1
    }

    method {scope-prefix define} {item begin beginPrefix end endPrefix} {
        foreach {kind prefix} [list begin $beginPrefix end $endPrefix] {
            if {[dict exists $myPrefixDict $prefix]} {
                error "Command definition confliction: gcloud $prefix"
            }
            dict set myPrefixDict $prefix \
                [dict merge $item \
                     [dict create \
                          trigger_verb $kind \
                          verbs [dict create $kind $prefix]]]
        }
    }

    method {scope-prefix take-name-arg} {argListVar specDict} {}
    method {scope-prefix name-arg} {specDict} {}
}
