#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ComDict {
    variable myGlobalOptions
    
    variable myPrefixList
    
    method accept args {
        # puts [list gcloud {*}$args]
        set globalOpts [$self take-global-options args]
        if {[set prefix [$self match-prefix $args]] eq ""} {
            return [list unknown $args]
        }
        list prefix $prefix global $globalOpts
    }
    
    method match-prefix argList {
        foreach prefix $myPrefixList {
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
                    lappend tobeRemoved $pos
                }
            }
            incr pos
        }
        
        set removedOpts []
        foreach pos [lreverse $tobeRemoved] {
            lappend removedOpts [lindex $argVar $pos]
            set argVar [lreplace $argVar $pos $pos]
        }
        set removedOpts
    }

    method {global-options add} option {
        # XXX: 重複検査
        dict set myGlobalOptions $option [dict create]
    }
    
    method {1arg-prefix add} argList {
        # XXX: 重複検査
        lappend myPrefixList $argList
    }
}
