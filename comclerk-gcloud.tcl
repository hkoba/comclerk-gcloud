#!/usr/bin/env tclsh
# -*- coding: utf-8; mode: tcl; tab-width: 4 -*-

package require snit

snit::type ComDict {
    variable myGlobalOptions
    
    variable myPrefixList
    
    method accept args {
        puts $args
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

snit::type comclerk-gcloud {
    component myInterp
    
    component myComDict
    delegate method accept to myComDict

    constructor args {

        # $self configurelist $args
        
        install myInterp using interp create $self.interp

        $myInterp alias gcloud \
            $self accept
        
        install myComDict using ComDict $self.comdict
        
        $myComDict global-options add project
        $myComDict global-options add zone
        $myComDict global-options add region
        
        $myComDict 1arg-prefix add {beta compute instances create}
        $myComDict 1arg-prefix add {compute instance-groups unmanaged create}
        $myComDict 1arg-prefix add {compute instance-groups set-named-ports}
        $myComDict 1arg-prefix add {compute instance-groups unmanaged add-instances}
        
        $myComDict 1arg-prefix add {compute addresses create}
        $myComDict 1arg-prefix add {compute health-checks create tcp}
        
        $myComDict 1arg-prefix add {compute backend-services create}
        $myComDict 1arg-prefix add {compute backend-services add-backend}
        
        $myComDict 1arg-prefix add {compute url-maps create}
        
        $myComDict 1arg-prefix add {compute ssl-certificates create}
        $myComDict 1arg-prefix add {compute target-https-proxies create}

        $myComDict 1arg-prefix add {compute firewall-rules create}
        
        $myComDict 1arg-prefix add {dns record-sets transaction start}
        $myComDict 1arg-prefix add {dns record-sets transaction add}
        $myComDict 1arg-prefix add {dns record-sets transaction execute}
        
        $myComDict 1arg-prefix add {alpha iap oauth-brands create}
        $myComDict 1arg-prefix add {alpha iap oauth-clients create}
        
        $myComDict 1arg-prefix add {compute backend-services update}
    }
    
    method source fn {
        $myInterp eval [list source $fn]
    }
}

if {![info level] && $::argv0 eq [info script]} {
    set self [comclerk-gcloud clerk]
    set argv [lassign $::argv fn]
    $self source $fn
}
