# check_scalelite
Icinga2 Plugin: Check Scalelite (BigBlueButton Loadbalancer)

This script check the state of Scalelite. Scalelite is a Loadbalancer-Solution for BigBlueButton. This Script based on this Project: https://github.com/blindsidenetworks/scalelite

Usage: ./check_scalelite.sh -w <Meetings,User,Video> -c <Meetings,User,Video> Example: ./check_scalelite.sh -w 10,150,25 -c 20,250,50

Parameter: -w STRING Warnung: Anzahl Meetings,User,Video -c STRING Kritisch: Anzahl Meetings,User,Video


Icinga2 Template:

    object CheckCommand "check_scalelite" {
    import "plugin-check-command"
     command = [ PluginDir + "/check_scalelite.sh" ]
    arguments += {
        "-c" = {
            description = "Kritische Anzahl: Meetings,User,Video"
            value = "$check_scalelite_critical$"
        }
        "-w" = {
            description = "Warrnung Anzahl: Meetings,Users,Video"
            value = "$check_scalelite_warning$"
        }
    }
    }

