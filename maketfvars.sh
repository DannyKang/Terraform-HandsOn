#!/bin/bash

##############################################
#     terraform.tfvars format
##############################################
# tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaaez4bhe5yolhq6ejskarrclgjutpvygfmtfoygk7eb2hak3426zfa"
# user_ocid = "ocid1.user.oc1..aaaaaaaa3xuu55fs4ma4rreu37z4xfskhgx6simgrzsyrtmli5fm35aabgna"
# fingerprint = "b0:95:77:c5:cb:26:6d:d7:dd:33:9a:2f:1e:3f:36:49"
# private_key_path ="/Users/kih/.oci/ges_oke.pem"
# region = "ap-seoul-1"


oci_config_path="/etc/oci/config"
ssh_private_key_path="/tmp/sshkey"


# Get tenancy from /etc/oci/config
while read line
do 
  tenancy_ocid=$(expr "$line" : "tenancy=\(.*\)")
  if [ $? -eq 0 ]; then
    echo "tenancy = \"$tenancy_ocid\"" >> terraform.tfvars
    break   
  fi
done < /etc/oci/config


# Get user ocid using "oci iam user list"
user_ocid=$(oci iam user list | jq '.data[] | select(.description == "inho.kang@oracle.com").id ')
echo "user_ocid = $user_ocid"  >> terraform.tfvars


# Make rsa key pair
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
chmod go-rwx ~/.oci/oci_api_key.pem
openssl rsa -pubout -in ~/.oci/oci_api_key.pem -out ~/.oci/oci_api_key_public.pem

un_user_ocid="${user_ocid%\"}"
un_user_ocid="${un_user_ocid#\"}" 
oci iam user api-key upload --user-id $un_user_ocid --key-file ~/.oci/oci_api_key_public.pem
#oci iam user api-key upload --user-id $user_ocid --key-file ~/.oci/oci_api_key_public.pem

fingerprint=$(openssl rsa -pubout -outform DER -in ~/.oci/oci_api_key_public.pem | openssl md5 -c)
fingerprint=${fingerprint#* }
echo "fingerprint = \"$fingerprint\""  >> terraform.tfvars
echo "private_key_path  = \"~/.oci/oci_api_key.pem\""  >> terraform.tfvars
echo "region = \"$OCI_CLI_PROFILE\"" >> terraform.tfvars




#fingerprint = "(stdin)= 88:a0:ed:3f:ea:19:ba:8b:d4:bc:5f:d3:9e:db:fc:88"

# TODO
# 1. To organize handson, variable setting file(terform.tfvars) should be copied into each chapters
#    ex) chapater1/terform.tfvars, chapter2/terform.tfvars
# 2. To access to VM, SSH pair is needed
#    ex) ssh-keygen -t rsa -N "" -b 2048 -C "<key_name>" -f <path/root_name>

# Make ssh key pair
ssh-keygen -t rsa -N "" -b 2048 -f ~/.ssh/vm_access_sshkey -q
echo "ssh_public_key = \"~/.ssh/vm_access_sshkey\""