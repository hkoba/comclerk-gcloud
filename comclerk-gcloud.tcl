#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require fileutil
package require snit

source [file dirname [::fileutil::fullnormalize [info script]]]/lib/comdict.tcl

snit::type comclerk {
    component myInterp

    variable myCommandDict [dict create]

    variable myKnownCommandsDict [dict create]
    
    # To allow arbitrary order editing.
    # (Note: original insertion order is kept in the dict itself)
    variable myCommandOrder [list]

    variable myLastCommandId

    constructor args {
        # $self configurelist $args
        install myInterp using interp create $self.interp
    }

    method install-comdict {aliasCmdName {comdict ""}} {
        $myInterp alias $aliasCmdName \
            $self add $aliasCmdName
        
        if {$comdict ne ""} {
            dict set myKnownCommandsDict $aliasCmdName $comdict
        }
    }

    method add {aliasCmdName args} {
        lappend myCommandOrder [set cid [incr myLastCommandId]]
        dict set myCommandDict $cid \
            [dict create \
                 cid $cid \
                 command [list $aliasCmdName {*}$args]]
    }

    method list-raw {} {
        set myCommandDict
    }
    
    method list-parsed {} {
        $self map-method parse-command {*}[dict values $myCommandDict]
    }

    method list {} {
        lmap cid $myCommandOrder {
            dict get $myCommandDict $cid
        }
    }

    method map-method {meth args} {
        $self map [list $self $meth] {*}$args
    }

    method map {commandPrefix args} {
        lmap cmdline $args {
            {*}$commandPrefix $cmdline
        }
    }

    method parse-command cmdline {
        dict set cmdline parsed [$self dispatch-comdict cmd $cmdline {
            $cmd accept {*}[dict get $cmdline command]
        }]
    }

    method stringify-command cmdline {
        $self dispatch-comdict cmd $cmdline {
            $cmd stringify [dict get $cmdline parsed]
        }
    }

    method dispatch-comdict {cmdVar cmdline script} {
        upvar 1 $cmdVar cmd
        lassign [dict get $cmdline command] cmdName
        if {[dict exists $myKnownCommandsDict $cmdName]} {
            set cmd [dict get $myKnownCommandsDict $cmdName]
            uplevel 1 $script
        }
    }

    method source fn {
        $myInterp eval [list source $fn]
    }
}

[ComDict comdict-gcloud] install {
    $self define-global-option project

    $self verbs set-completer verbsDict {
        set known [dict create]
        set missing [dict create]
        dict for {verb prefix} $verbsDict {
            if {$prefix eq "-"} {
                dict set missing $verb $prefix
            } else {
                dict set known $verb $prefix
            }
        }
        if {[dict exists $known create]
            && [lindex [dict get $known create] end] eq "create"} {
            # create が与えられて、他の動詞を補えば良いケース
            foreach verb [dict keys $missing] {
                dict set verbsDict $verb \
                    [lreplace [dict get $known create] end end $verb]
            }
        } else {
            
        }
        set verbsDict
    }

    $self define 1arg-prefix vm \
        create {beta compute instances create} \
        delete -

    $self define 1arg-prefix ig/unmanaged \
        create {compute instance-groups unmanaged create} \
        delete -        

    $self define 1arg-prefix {ig named-port} \
        {set named-port} {compute instance-groups set-named-ports}

    $self define 1arg-prefix {ig vm} \
        {add vm} {compute instance-groups unmanaged add-instances}

    $self define 1arg-prefix address \
        create {compute addresses create} \
        delete -        

    $self define 1arg-prefix health-check \
        create {compute health-checks create tcp} \
        delete {compute health-checks delete}

    $self define 1arg-prefix {lb backend-service} \
        create {compute backend-services create} \
        delete -

    $self define 1arg-prefix {lb backend-service backend} \
        {add ig} {compute backend-services add-backend}

    $self define 1arg-prefix {lb url-map} \
        create {compute url-maps create} \
        delete -

    $self define 1arg-prefix ssl-certificate \
        create {compute ssl-certificates create} \
        delete -
        
    $self define 1arg-prefix {lb target-https-proxie} \
        create {compute target-https-proxies create} \
        delete -

    $self define 1arg-prefix firewall-rule \
        create {compute firewall-rules create} \
        delete -

    $self define scope-prefix {dns record-set} \
        begin {dns record-sets transaction start} \
        end {dns record-sets transaction execute}
    $self define 1arg-prefix {dns record-set} \
        add {dns record-sets transaction add}

    $self define named-arg-prefix {iap oauth-brand} \
        create application_title {alpha iap oauth-brands create} \
        delete -

    $self define 1arg-prefix {iap oauth-client} \
        create {alpha iap oauth-clients create} \
        delete -

    $self define 1arg-prefix {backend-service *} \
        update {compute backend-services update}
}


snit::widget comclerk-ui {
    component myText

    component myClerk

    constructor args {
       install myClerk using from args -clerk ""
       install myText using text $win.text \
           -wrap none
       pack $myText -fill both -expand yes
    }

    method add accepted {
        $myText insert end [$myClerk stringify $accepted]
    }
}

if {![info level] && $::argv0 eq [info script]} {

    set argv [lassign $::argv fn]

    set clerk clerk

    comclerk $clerk

    $clerk install-comdict gcloud comdict-gcloud

    $clerk source $fn
    
    # foreach line [$clerk map-method stringify-command {*}[$clerk list-parsed]] {
    #     puts $line
    # }

    foreach cmdline [$clerk list-parsed] {
        $clerk dispatch-comdict cmd $cmdline {
            set parsed [dict get $cmdline parsed]
            if {[dict get $parsed verb] eq "create"} {
                puts [$cmd stringify-verb delete $parsed]
            } else {
                # puts "parsed: $parsed"
            }
        }
    }
}
