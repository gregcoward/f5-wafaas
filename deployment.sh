#!/bin/bash
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin/"

IP_REGEX='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'

while getopts m:d:n:h:s:t:l:b:a:w:k:u:p:v: option
do	case "$option"  in
        m) mode=$OPTARG;;
        d) deployment=$OPTARG;;
	    n) pool_member=$OPTARG;;
        h) pool_http_port=$OPTARG;;
        s) pool_https_port=$OPTARG;;
        t) type=$OPTARG;;
        l) level=$OPTARG;;
        b) logging_node=$OPTARG;;
        a) policy=$OPTARG;;
        w) oms_workspace=$OPTARG;;
        k) oms_key=$OPTARG;;
        u) user=$OPTARG;;
        p) passwd=$OPTARG;;
        v) vipip=$OPTARG;;
    esac 
done

vs_http_port="880"
vs_https_port="8445"

#sleep 120

# download canned or custom security policy and create accompanying ltm policy
custom_policy="none"
ltm_policy_name="/Common/$deployment-ltm_policy" 
     
if [[ $level == "custom" ]]; then
     if [[ -n $policy && $policy != "NOT_SPECIFIED" ]]; then
          custom_policy=$policy
     else 
          level="high"
     fi
fi

# deploy policies
# profile name
l7dos_name="/Common/$deployment-l7dos"

response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'","partition":"'"Common"'","deviceGroup":"none","strictUpdates":"disabled","template":"/Common/f5.policy_creator_beta","trafficGroup":"none","lists":[],"variables":[{"name":"variables__deployment","encrypted":"no","value":"'"$deployment"'"},{"name":"variables__type","encrypted":"no","value":"'"$type"'"},{"name":"variables__level","encrypted":"no","value":"'"$level"'"},{"name":"variables__do_asm","encrypted":"no","value":"true"},{"name":"variables__do_l7dos","encrypted":"no","value":"true"},{"name":"variables__custom_asm_policy","encrypted":"no","value":"'"$custom_policy"'"}]}' -o /dev/null)

if [[ $response_code != 200  ]]; then
     echo "Failed to install LTM policy; exiting with response code '"$response_code"'"
     exit
fi

# deploy logging profiles
# profile names
deployment_name="$deployment-azure-log"
asm_log_name="/Common/${deployment}-${oms_workspace}.app/${deployment}-${oms_workspace}_lp_asm_logging_offbox"
dos_log_name="/Common/${deployment}-${oms_workspace}.app/${deployment}-${oms_workspace}_lp_l7dos_logging_offbox"
local_log_name="Log illegal requests"

response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$oms_workspace"'","partition":"'"Common"'","deviceGroup":"none","strictUpdates":"disabled","template":"/Common/f5.asm_log_creator_beta","trafficGroup":"none","variables":[{"name":"variables__key","encrypted":"no","value":"'"$oms_key"'"},{"name":"variables__workspace","encrypted":"no","value":"'"$oms_workspace"'"},{"name":"variables__loggingnode","encrypted":"no","value":"'"$logging_node"'"}]}' -o /dev/null)

if [[ $response_code != 200  ]]; then
    echo "Failed to install logging profiles; exiting with response code '"$response_code"'"
    exit $response_code
else
     echo "Logging deployment succeeded."
fi

# pre-create node
if [[ $pool_member =~ $IP_REGEX ]]; then
    response_json=$(curl -sku $user:$passwd -X GET -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node | jq .items[].address )
    if [[ $response_json != *$pool_member* ]]; then
        response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node -d '{"name": "'"$pool_member"'","partition": "'"Common"'","address": "'"$pool_member"'"}' -o /dev/null)
    else
        response_code=200
    fi
else
    response_json=$(curl -sku $user:$passwd -X GET -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node | jq .items[].fqdn.tmName )
    if [[ $response_json != *$pool_member* ]]; then
        response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/node -d '{"name": "'"$pool_member"'","partition": "'"Common"'","fqdn": {"autopopulate": "enabled","tmName": "'"$pool_member"'"}}' -o /dev/null)
    else
        response_code=200
    fi
fi

if [[ $response_code != 200  ]]; then
     echo "Failed to create node; with response code '"$response_code"'"
     exit $response_code
fi

sleep 10

# deploy unencrypted application
if [[ $mode == "http" || $mode == "http-https" ]]; then        
     response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_http_port"'","partition":"'"Common"'","deviceGroup":"none","strictUpdates":"disabled","template":"/Common/f5.http.v1.2.0rc4","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_http_port"'","0"]}]},{"name":"server_pools__servers"}],"variables":[{"name":"asm__security_logging","encrypted":"no","value":"Log illegal requests"},{"name":"asm__use_asm","encrypted":"no","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","encrypted":"no","value":"/'"Common"'/http"},{"name":"pool__addr","encrypted":"no","value":"'"$vipip"'"},{"name":"pool__mask","encrypted":"no","value":"255.255.255.255"},{"name":"pool__persist","encrypted":"no","value":"/#cookie#"},{"name":"pool__port","encrypted":"no","value":"'"$vs_http_port"'"},{"name":"pool__profiles","encrypted":"no","value":"'"$l7dos_name"'"},{"name":"ssl__mode","encrypted":"no","value":"no_ssl"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy unencrypted application; exiting with response code '"$response_code"'"
          exit
     else
          response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X PATCH -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/virtual/~Common~${deployment}-${vs_http_port}.app~${deployment}-${vs_http_port}_vs -d '{"securityLogProfiles":["'"$asm_log_name"'" "'"$dos_log_name"'"]}' -o /dev/null)
          
          if [[ $response_code != 200  ]]; then
               echo "Failed to modify logging profiles; exiting with response code '"$response_code"'"
               exit
          fi
     fi
fi

if [[ $mode == "https" || $mode == "http-https" || $mode == "https-offload" ]]; then 

     # locate cert/key pair for encrypted deployment
     cert_path=`find -H /var/lib/waagent -type f -name "$thumbprint.crt"`
     cert_name=`echo $cert_path | grep -oP "^/var/lib/waagent/\K.*"`
     cp $cert_path /config/ssl/

     key_path=`find -H /var/lib/waagent -type f -name "$thumbprint.prv"`
     key_name=`echo $key_path | grep -oP "^/var/lib/waagent/\K.*"`
     cp $key_path /config/ssl/

     # install cert and key on BIG-IP
     response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/crypto/cert -d '{"command": "install","name": "'"$deployment"'-cert","options": [ { "from-local-file": "/config/ssl/'"$cert_name"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install SSL cert; exiting with response code '"$response_code"'"
          exit
     fi
     
     response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/crypto/key -d '{"command": "install","name": "'"$deployment"'-key","options": [ { "from-local-file": "/config/ssl/'"$key_name"'" } ] }' -o /dev/null)
     if [[ $response_code != 200  ]]; then
          echo "Failed to install SSL key; exiting with response code '"$response_code"'"
          exit
     fi

     if [[ $? == 0 ]]; then
          # delete local cert and key
          rm -rf /config/ssl/$cert_name
          rm -rf /config/ssl/$key_name
          rm -rf $cert_path
          rm -rf $key_path

          # output cert and key variables for use by the iApp
          cert="/Common/$deployment-cert.crt"
          key="/Common/$deployment-key.key"
          chain="/Common/ca-bundle.crt"
     else 
          echo "Failed to create cert/key, using defaults instead."
          cert="/Common/default.crt"
          key="/Common/default.key"
          chain="/Common/ca-bundle.crt"
     fi
fi

# deploy encrypted application
if [[ $mode == "https" || $mode == "http-https" ]]; then      
     response_code=$(curl -sk -u $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_https_port"'","partition":"'"Common"'","deviceGroup":"'"$device_group"'","strictUpdates":"disabled","template":"/Common/f5.http.v1.2.0rc4","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port_secure","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_https_port"'","0"]}]},{"name":"server_pools__servers"}],"variables":[{"name":"asm__security_logging","encrypted":"no","value":"Log illegal requests"},{"name":"asm__use_asm","encrypted":"no","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","encrypted":"no","value":"/'"Common"'/https"},{"name":"pool__addr","encrypted":"no","value":"'"$vipip"'"},{"name":"pool__mask","encrypted":"no","value":"255.255.255.255"},{"name":"pool__persist","encrypted":"no","value":"/#cookie#"},{"name":"pool__port","encrypted":"no","value":"'"$vs_http_port"'"},{"name":"pool__port_secure","encrypted":"no","value":"'"$vs_https_port"'"},{"name":"pool__redirect_to_https","encrypted":"no","value":"no"},{"name":"pool__profiles","encrypted":"no","value":"'"$l7dos_name"'"},{"name":"ssl__cert","encrypted":"no","value":"'"$cert"'"},{"name":"ssl__key","encrypted":"no","value":"'"$key"'"},{"name":"ssl__mode","encrypted":"no","value":"client_ssl_server_ssl"},{"name":"ssl__server_ssl_profile","encrypted":"no","value":"/#default#"},{"name":"ssl__use_chain_cert","encrypted":"no","value":"'"$chain"'"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy encrypted application; exiting with response code '"$response_code"'"
          exit
    else
           response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X PATCH -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/virtual/~Common~${deployment}-${vs_https_port}.app~${deployment}-${vs_https_port}_vs -d '{"securityLogProfiles":["'"$asm_log_name"'" "'"$dos_log_name"'"]}' -o /dev/null)
          
          if [[ $response_code != 200  ]]; then
               echo "Failed to modify logging profiles; exiting with response code '"$response_code"'"
               exit
          fi
     fi
fi

# deploy offloaded application
if [[ $mode == "https-offload" ]]; then           
     response_code=$(curl -sk -u $user:$passwd -w "%{http_code}" -X POST -H "Content-Type: application/json" https://localhost/mgmt/tm/sys/application/service/ -d '{"name":"'"$deployment"'-'"$vs_https_port"'","partition":"'"Common"'","deviceGroup":"'"$device_group"'","strictUpdates":"enabled","template":"/Common/f5.http.v1.2.0rc4","trafficGroup":"none","tables":[{"name":"pool__hosts","columnNames":["name"],"rows":[{"row":["'"$deployment"'"]}]},{"name":"pool__members","columnNames":["addr","port","connection_limit"],"rows":[{"row":["'"$pool_member"'","'"$pool_http_port"'","0"]}]},{"name":"server_pools__servers"}],"variables":[{"name":"asm__security_logging","encrypted":"no","value":"Log illegal requests"},{"name":"asm__use_asm","encrypted":"no","value":"'"$ltm_policy_name"'"},{"name":"monitor__monitor","encrypted":"no","value":"/'"Common"'/http"},{"name":"pool__addr","encrypted":"no","value":"'"$vipip"'"},{"name":"pool__mask","encrypted":"no","value":"255.255.255.255"},{"name":"pool__persist","encrypted":"no","value":"/#cookie#"},{"name":"pool__port_secure","encrypted":"no","value":"'"$vs_https_port"'"},{"name":"pool__redirect_to_https","encrypted":"no","value":"no"},{"name":"pool__profiles","encrypted":"no","value":"'"$l7dos_name"'"},{"name":"ssl__cert","encrypted":"no","value":"'"$cert"'"},{"name":"ssl__key","encrypted":"no","value":"'"$key"'"},{"name":"ssl__mode","encrypted":"no","value":"client_ssl"},{"name":"ssl__use_chain_cert","encrypted":"no","value":"'"$chain"'"}]}' -o /dev/null)

     if [[ $response_code != 200  ]]; then
          echo "Failed to deploy SSL offloaded application; exiting with response code '"$response_code"'"
          exit
     else 
           response_code=$(curl -sku $user:$passwd -w "%{http_code}" -X PATCH -H "Content-Type: application/json" https://localhost/mgmt/tm/ltm/virtual/~Common~${deployment}-${vs_https_port}.app~${deployment}-${vs_https_port}_vs -d '{"securityLogProfiles":["'"$asm_log_name"'" "'"$dos_log_name"'"]}' -o /dev/null)
          
          if [[ $response_code != 200  ]]; then
               echo "Failed to modify logging profiles; exiting with response code '"$response_code"'"
               exit
          fi
     fi
fi

echo "Deployment complete."
exit