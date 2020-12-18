#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require fileutil
package require snit

source [file dirname [::fileutil::fullnormalize [info script]]]/lib/comdict.tcl

snit::type comclerk {
    option -add-command ""

    component myInterp

    variable myKnownCommandsDict [dict create]

    constructor args {
        $self configurelist $args
        install myInterp using interp create $self.interp
    }

    method install-comdict {aliasCmdName comdict} {
        dict set myKnownCommandsDict $aliasCmdName $comdict
        $myInterp alias $aliasCmdName \
            $self accept $aliasCmdName
    }

    method accept {aliasCmdName args} {
        set comdict [dict get $myKnownCommandsDict $aliasCmdName]
        set accepted [$comdict accept {*}$args]
        dict set accepted command $aliasCmdName
        if {$options(-add-command) ne ""} {
            uplevel #0 [list {*}$options(-add-command) $accepted]
        } elseif {[dict exists $accepted name]} {
            puts $accepted
            puts "# [dict get $accepted name] :: [dict get $accepted resource]"
        }
    }

    method stringify accepted {
        set comdict [dict get $myKnownCommandsDict [dict get $accepted command]]
        $comdict stringify $accepted
    }

    method source fn {
        $myInterp eval [list source $fn]
    }
}

[ComDict comdict-gcloud] install {
    $self define-global-option project

    $self define 1arg-prefix vm \
        create {beta compute instances create}

    $self define 1arg-prefix ig/unmanaged \
        create {compute instance-groups unmanaged create}
    $self define 1arg-prefix {ig named-port} \
        {set named-port} {compute instance-groups set-named-ports}
    $self define 1arg-prefix {ig vm} \
        {add vm} {compute instance-groups unmanaged add-instances}

    $self define 1arg-prefix address \
        create {compute addresses create}
    $self define 1arg-prefix health-check \
        create {compute health-checks create tcp}

    $self define 1arg-prefix {lb backend-service} \
        create {compute backend-services create}
    $self define 1arg-prefix {lb backend-service backend} \
        {add ig} {compute backend-services add-backend}

    $self define 1arg-prefix {lb url-map} \
        create {compute url-maps create}

    $self define 1arg-prefix ssl-certificate \
        create {compute ssl-certificates create}
    $self define 1arg-prefix {lb target-https-proxie} \
        create {compute target-https-proxies create}

    $self define 1arg-prefix firewall-rule \
        create {compute firewall-rules create}

    $self define scope-prefix {dns record-set} \
        begin {dns record-sets transaction start} \
        end {dns record-sets transaction execute}
    $self define 1arg-prefix {dns record-set} \
        add {dns record-sets transaction add}

    $self define named-arg-prefix {iap oauth-brand} \
        create application_title {alpha iap oauth-brands create}
    $self define 1arg-prefix {iap oauth-client} \
        create {alpha iap oauth-clients create}

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
        $myText insert end [$myClerk stringify $accepted]\n
    }
}

if {![info level] && $::argv0 eq [info script]} {

    set win .win
    set clerk clerk

    pack [comclerk-ui $win -clerk $clerk] -fill both -expand yes

    comclerk $clerk \
        -add-command [list $win add]

    $clerk install-comdict gcloud comdict-gcloud

    set argv [lassign $::argv fn]
    $clerk source $fn
}
