#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ComDict {
    variable myGlobalOptions
    
    variable myPrefixDict [dict create]
    
    method accept args {
        # puts [list gcloud {*}$args]
        set globalOpts [$self take-global-options args]
        if {[set prefix [$self match-prefix $args]] eq ""} {
            return
        }
        set matched [dict get $myPrefixDict $prefix]
        set rest [lrange $args [llength $prefix] end]
        dict with matched {
            set name [$self $kind get-name rest $matched]
            dict create verb $trigger_verb resource $resource \
                name $name prefix $prefix options $rest \
                {*}$globalOpts
        }
    }

    method stringify accepted {
        # XXX: name!
        # XXX: named-arg-prefix, scope-prefix
        append cmd "[dict get $accepted command] --[dict get $accepted project] [dict get $accepted prefix] \\\n"
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
        set item [$self $prefixKind configure \
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

    method {1arg-prefix configure} {item action prefix args} {
        dict merge $item \
            [dict create \
                 trigger_verb $action \
                 verbs [dict create $action $prefix {*}$args]]
    }

    method {1arg-prefix get-name} {argListVar specDict} {
        upvar 1 $argListVar argList
        set argList [lassign $argList name]
        set name
    }

    method {named-arg-prefix configure} {item action nameArg prefix args} {
        dict merge $item \
            [dict create \
                 trigger_verb $action \
                 nameArg $nameArg \
                 verbs [dict create $action $prefix {*}$args]]
    }
    
    method {named-arg-prefix get-name} {argListVar specDict} {
        upvar 1 $argListVar argList
        set nameArg [dict get $specDict nameArg]
        foreach arg $argList {
            if {[regexp {^--(\w+)=(.*)} $arg -> name value]
                && $name eq $nameArg
            } {
                return $value
            }
        }
    }

    method {scope-prefix configure} {item begin beginPrefix end endPrefix} {
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

    method {scope-prefix get-name} {argListVar specDict} {
        ;# nop
    }
}
