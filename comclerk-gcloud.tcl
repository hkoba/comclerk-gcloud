#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require fileutil
package require snit

source [file dirname [::fileutil::fullnormalize [info script]]]/lib/comdict.tcl

snit::type comclerk-gcloud {
    option -add-command ""

    component myInterp
    
    constructor args {

        $self configurelist $args
        
        install myInterp using interp create $self.interp

        $myInterp alias gcloud \
            $self accept
    }
    
    method accept args {
        set accepted [$ourKnownCmd accept {*}$args]
        if {$options(-add-command) ne ""} {
            uplevel #0 [list {*}$options(-add-command) $accepted]
        } elseif {[dict exists $accepted name]} {
            puts $accepted
            puts "# [dict get $accepted name] :: [dict get $accepted resource]"
        }
    }

    method source fn {
        $myInterp eval [list source $fn]
    }

    typevariable ourKnownCmd

    typeconstructor {
        set ourKnownCmd [ComDict $type.comdict]
        
        $ourKnownCmd global-options add project
        # $ourKnownCmd global-options add region
        # $ourKnownCmd global-options add zone
        
        $ourKnownCmd 1arg-prefix add vm \
            create {beta compute instances create}
        
        $ourKnownCmd 1arg-prefix add ig/unmanaged \
            create {compute instance-groups unmanaged create}
        $ourKnownCmd 1arg-prefix add {ig named-port} \
            {set named-port} {compute instance-groups set-named-ports}
        $ourKnownCmd 1arg-prefix add {ig vm} \
            {add vm} {compute instance-groups unmanaged add-instances}
        
        $ourKnownCmd 1arg-prefix add address \
            create {compute addresses create}
        $ourKnownCmd 1arg-prefix add health-check \
            create {compute health-checks create tcp}
        
        $ourKnownCmd 1arg-prefix add {lb backend-service} \
            create {compute backend-services create}
        $ourKnownCmd 1arg-prefix add {lb backend-service backend} \
            {add ig} {compute backend-services add-backend}
        
        $ourKnownCmd 1arg-prefix add {lb url-map} \
            create {compute url-maps create}
        
        $ourKnownCmd 1arg-prefix add ssl-certificate \
            create {compute ssl-certificates create}
        $ourKnownCmd 1arg-prefix add {lb target-https-proxie} \
            create {compute target-https-proxies create}

        $ourKnownCmd 1arg-prefix add firewall-rule \
            create {compute firewall-rules create}
        
        $ourKnownCmd scope-prefix add {dns record-set} \
            begin {dns record-sets transaction start} \
            end {dns record-sets transaction execute}
        $ourKnownCmd 1arg-prefix add {dns record-set} \
            add {dns record-sets transaction add}
        
        $ourKnownCmd named-arg-prefix add {iap oauth-brand} \
            create application_title {alpha iap oauth-brands create}
        $ourKnownCmd 1arg-prefix add {iap oauth-client} \
            create {alpha iap oauth-clients create}
        
        $ourKnownCmd 1arg-prefix add {backend-service *} \
            update {compute backend-services update}
    }
}

snit::widget comclerk-ui {
    component myText

    constructor args {
        install myText using text $win.text
        pack $myText -fill both -expand yes
    }

    method add accepted {
        $myText insert end $accepted
    }
}

if {![info level] && $::argv0 eq [info script]} {
    
    pack [set self [comclerk-ui .win]] -fill both -expand yes
    
    set clerk [comclerk-gcloud clerk \
                   -add-command [list $self add]]
    set argv [lassign $::argv fn]
    $clerk source $fn
}
