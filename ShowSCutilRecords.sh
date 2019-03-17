#!/bin/bash
#
# Short:    Shell Functions that query SCutil records and parse the results
# Author:   Mark J Swift
# Version:  1.0.1
# Modified: 17-Mar-2019
#
# ShowSCutilRecords provides two main functions that allow you to read and parse the SCutil values.
# You should note that at first boot, the SCutil vars take some time to fully populate.
#
# SF_SCUTILSHOWALLRECORDSFLAT - This function will shows every record of every SubKey, flattened to be more easily accessible
# SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT - Given an existing record, this function will show all associated subrecords
#
# I use diff on the results of the SF_SCUTILSHOWALLRECORDSFLAT output to see what changes when you connect to different networks.
#
#
# Example1 - List all SCutil records and values
#
#   SF_SCUTILSHOWALLRECORDSFLAT
#
#   The output will be a very long list something like this:
#
#   Setup,,CurrentSet,/Sets/73C34124-C002-4A12-9A3D-106EF116DC71
#   Setup,,LastUpdated,05/29/2015 15:35:21
#   Setup,/,UserDefinedName,Automatic
#   Setup,/Network/Global/IPv4,ServiceOrder,0,0F4E1ECE-F004-445D-8923-6B03B9C81D79
#   Setup,/Network/Global/IPv4,ServiceOrder,1,1DDF4F0B-E41C-45CD-AD3F-5B44A5F512F9
#   Setup,/Network/Global/IPv4,ServiceOrder,2,0DF2F1A0-76F4-42F6-828C-C3E98C391338
#   Setup,/Network/Global/IPv4,ServiceOrder,3,9804EAB2-718C-42A7-891D-79B73F91CA4B
#   Setup,/Network/Global/IPv4,ServiceOrder,4,2D79CD84-3003-4F99-8518-F91DECCC1CFD
#   Setup,/Network/HostNames,LocalHostName,afielk-m0sy1i4g
#   Setup,/Network/Interface/en1/AirPort,JoinModeFallback,0,DoNothing
#   Setup,/Network/Interface/en1/AirPort,PowerEnabled,TRUE
#   Setup,/Network/Interface/en1/AirPort,RememberJoinedNetworks,TRUE
#   Setup,/Network/Interface/en1/AirPort,Version,2200
#   ...
#   com.apple.smb,SigningEnabled,TRUE
#   com.apple.smb,SigningRequired,FALSE
#   com.apple.smb,TransportKeepAlive,120
#   com.apple.smb,VirtualAdminShares,TRUE
#   com.apple.smb,VirtualHomeShares,TRUE
#
#
# Example 2 - List all IPv4 settings of network interface  en1
#
#   SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT "State,/Network/Interface/en1/IPv4"
#
#   The output will be a list something like this:
#
#   State,/Network/Interface/en1/IPv4,Addresses,0,192.168.0.4
#   State,/Network/Interface/en1/IPv4,BroadcastAddresses,0,192.168.0.255
#   State,/Network/Interface/en1/IPv4,SubnetMasks,0,255.255.255.0
#
#
# Example 3 - Get the IPv4 address of network interface en1
#
#   SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT "State,/Network/Interface/en1/IPv4,Addresses,0"
#
#   The output will be a single line, something like this:
#
#   State,/Network/Interface/en1/IPv4,Addresses,0,192.168.0.4
#
#
# Example 4 - Get DHCP option 15 (domain name)
#
#   # Get the Primary network service
#   sv_IPv4PrimaryService=$(SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT "State,/Network/Global/IPv4,PrimaryService" | cut -d, -f4-)
#
#   # Get DHCP option 15 (domain name)
#   sv_NetworkServiceDHCPOption15=$(SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT "State,/Network/Service/${sv_IPv4PrimaryService}/DHCP,Option_15" | cut -d, -f4- | sed -E "s/^<data> 0x//;s/00$//" | xxd -r -p)
#   echo ${sv_NetworkServiceDHCPOption15}
#
#   This will display the domain name as supplied by DHCP option 15, something like this
#
#   yourcompany.com
#
#

# -- Begin ShowSCutilRecords internal functions --

SV_SCUTILDATASEPARATOR=","

# Shows all available SCutil SubKeys
SF_SCUTILSHOWALLSUBKEYS()
{
  (SCutil | grep -v "{\|}" | sed -E "s|^[^=]*=[ ]*(.*$)|\1|g") <<- EOF
open
list
quit
EOF
}

# Shows all records for a subkey, tidied up to be more easily parsable
SF_SCUTILSHOWALLRECORDSFORSUBKEYTIDY() #subkey
{
  if test -n "${1}"
  then
    if ($(echo ${1} | grep -q ":"))
    then
      echo "$(echo ${1} | cut -d':' -f1)"" : <dictionary>"
      echo "{"
      echo -n "$(echo ${1} | cut -d":" -f2-) : "
    else
      echo -n "${1} : "
    fi
    (SCutil | sed -E 's|^([^: ]*)[ ]*:[ ]*(.*)$|\1 : \2|;s|^[ ]*||g;s|[ ]*{[ ]*|{|g;s|[ ]*}[ ]*|}|g;s|[ ]*$||g;s|{|\
{\
|g;s|}|\
}\
|g' | tr -s '\n') <<- EOF
open
show ${1}
quit
EOF
    if ($(echo ${1} | grep -q ":"))
    then
      echo "}"
    fi
  fi
}

# Shows all records for a subkey, flattened to be more easily accessible
SF_SCUTILSHOWALLRECORDSFORSUBKEYFLAT() #subkey
{
  local sv_LastStruct
  local sv_PreText
  local sv_SCutilText
  
  if test -n "${1}"
  then
    sv_LastStruct=""
    sv_PreText=""
    SF_SCUTILSHOWALLRECORDSFORSUBKEYTIDY ${1} | while IFS= read sv_SCutilText
    do
      if [ "${sv_SCutilText}" = "{" ]
      then
        if test -n "${sv_PreText}"
        then
          sv_PreText="${sv_PreText}${SV_SCUTILDATASEPARATOR}"
        fi
        sv_PreText="${sv_PreText}${sv_LastStruct}"
        sv_LastStruct=""
      else
        if [ "${sv_SCutilText}" = "}" ]
        then
          sv_PreText="$(echo ${sv_PreText} | sed -E 's|(.*)('${SV_SCUTILDATASEPARATOR}'[^'${SV_SCUTILDATASEPARATOR}']*$)|\1|')"
        else
          if ($(echo ${sv_SCutilText} | grep -q "<[^<>]*>$"))
          then
            sv_LastStruct="$(echo "${sv_SCutilText}" | sed -E 's|^(.*) : ([^:]*)$|\1|')"
          else
            if test -n "${sv_PreText}"
            then
              echo -n "${sv_PreText}${SV_SCUTILDATASEPARATOR}"
            fi
            echo ${sv_SCutilText} | sed -E 's|^(.*) : (.*)$|\1'${SV_SCUTILDATASEPARATOR}'\2|'
          fi
	    fi      
      fi      
    done
  fi
}

# Given a flat record, return the associated SubKey
SF_SCUTILFINDSUBKEYFORFLATRECORD() #flatrecord
{
  local sv_SubKey
  local iv_Count
  
  if test -n "${1}"
  then
    sv_SubKey=""
    iv_Count=$(echo ${1} | tr "${SV_SCUTILDATASEPARATOR}" "\n" | wc -l | sed "s|^[ ]*||")
    while [ ${iv_Count} -gt 0 ]
    do
      sv_SubKey=$(echo ${1} | cut -d"${SV_SCUTILDATASEPARATOR}" -f1-${iv_Count})
      if test -n "$(SF_SCUTILSHOWALLSUBKEYS | sed -E 's|(^[^:]*):|\1,|' | grep "${sv_SubKey}")"
      then
        echo "${sv_SubKey}" | sed -E 's|(^[^'${SV_SCUTILDATASEPARATOR}']*)'${SV_SCUTILDATASEPARATOR}'|\1:|'
        break
      fi
      iv_Count=$((${iv_Count}-1))
    done
  fi
}

# -- End ShowSCutilRecords internal functions --


# -- Begin ShowSCutilRecords functions --

# Shows every record of every SubKey, flattened to be more easily accessible
SF_SCUTILSHOWALLRECORDSFLAT()
{
  local sv_SCutilSubKey

  SF_SCUTILSHOWALLSUBKEYS | while read sv_SCutilSubKey
  do
    SF_SCUTILSHOWALLRECORDSFORSUBKEYFLAT ${sv_SCutilSubKey}
  done
}

# Given an existing flat record, this function will show all associated subrecords
SF_SCUTILSHOWALLSUBRECORDSFORRECORDFLAT() #flatrecord
{
  local sv_SubKeyForRecord
  
  if test -n "${1}"
  then
    sv_SubKeyForRecord="$(SF_SCUTILFINDSUBKEYFORFLATRECORD ${1})"
    if test -n "${sv_SubKeyForRecord}"
    then
      SF_SCUTILSHOWALLRECORDSFORSUBKEYFLAT "${sv_SubKeyForRecord}" | grep -E "${1}("${SV_SCUTILDATASEPARATOR}"|$)"
    fi
  fi
}

# -- End ShowSCutilRecords functions --

# Now we begin for real

SF_SCUTILSHOWALLRECORDSFLAT

#exit 0

