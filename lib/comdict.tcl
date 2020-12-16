#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ComDict {
    variable myGlobalOptions
    
    variable myPrefixDict
    
    variable myTranslatorDict [dict create]
    
    method accept args {
        # puts [list gcloud {*}$args]
        set globalOpts [$self take-global-options args]
        if {[set prefix [$self match-prefix $args]] eq ""} {
            return [list unknown $args]
        }
        $self translate-by $prefix $globalOpts \
            [lrange $args [llength $prefix] end]
    }
    
    method {translator add} {verb command} {
        dict set myTranslatorDict $verb $command
    }

    method translate-by {prefix global argList} {
        set matched [dict get $myPrefixDict $prefix]
        set verb [dict get $matched trigger-verb]
        if {[dict exists $myTranslatorDict $verb]} {
            {*}[dict get $myTranslatorDict $verb] \
                [dict remove $matched trigger-verb] $global {*}$argList
        } else {
            list matched $matched global $global args $argList
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
        # XXX: 重複検査
        dict set myPrefixDict $prefix \
            [dict create \
                 resource $resource \
                 trigger-verb $action \
                 $action $prefix {*}$args]
    }
}
