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
            return [list unknown $args]
        }
        set matched [dict get $myPrefixDict $prefix]
        set rest [lrange $args [llength $prefix] end]
        dict with matched {
            set name [$self $kind get-name rest $matched]
            dict create verb $trigger_verb resource $resource \
                name $name options $rest \
                {*}$globalOpts
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

    method {global-options add} option {
        # XXX: 重複検査
        dict set myGlobalOptions $option [dict create]
    }

    method {1arg-prefix add} {resource action prefix args} {
        if {[dict exists $myPrefixDict $prefix]} {
            error "Command definition confliction: gcloud $prefix"
        }
        dict set myPrefixDict $prefix \
            [dict create \
                 kind 1arg-prefix \
                 resource $resource \
                 trigger_verb $action \
                 verbs [dict create $action $prefix {*}$args]]
    }

    method {1arg-prefix get-name} {argListVar specDict} {
        upvar 1 $argListVar argList
        set argList [lassign $argList name]
        set name
    }

    method {named-arg-prefix add} {resource action nameArg prefix args} {
        dict set myPrefixDict $prefix \
            [dict create \
                 kind named-arg-prefix \
                 resource $resource \
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

    method {scope-prefix add} {resource begin beginPrefix end endPrefix} {
        foreach {kind prefix} [list begin $beginPrefix end $endPrefix] {
            if {[dict exists $myPrefixDict $prefix]} {
                error "Command definition confliction: gcloud $prefix"
            }
            dict set myPrefixDict $prefix \
                [dict create \
                     kind scope-prefix \
                     resource $resource \
                     trigger_verb $kind \
                     verbs [dict create $kind $prefix]]
        }
    }

    method {scope-prefix get-name} {argListVar specDict} {
        ;# nop
    }
}
