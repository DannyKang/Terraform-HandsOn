variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "region" {}

variable "compartment_ocid" {}
variable "ssh_public_key" {}
variable "ssh_private_key" {}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key_path = var.private_key_path
  region           = var.region
}


#Pre-Requisite
# Compartment should be made

# 1. Make VCN

# Create VCN

################## VCN ##########################

resource "oci_core_vcn" "tf_handson_vcn" {
  cidr_block     = "10.1.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "TFHandsOnVcn"
  dns_label      = "tfvcn"
}

############## Internet Gateway #################
resource "oci_core_internet_gateway" "tf_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = TFInternetGateway
  vcn_id         = oci_core_vcn.tf_handson_vcn.id
}

############## Route Table #################
resource "oci_core_default_route_table" "default_route_table" {
  manage_default_resource_id = oci_core_vcn.test_vcn.default_route_table_id
  display_name               = "DefaultRouteTable"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.tf_internet_gateway.id
  }
}

############## Subnet #################
resource "oci_core_subnet" "tf_subnet" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  cidr_block          = "10.1.20.0/24"
  display_name        = "TFHandsOnSubnet"
  dns_label           = "tfsubnet"
  security_list_ids   = [oci_core_vcn.tf_handson_vcn.tf_sl_web]
  compartment_id      = var.compartment_ocid
  vcn_id              = oci_core_vcn.tf_handson_vcn.id
  route_table_id      = oci_core_vcn.test_vcn.default_route_table_id
  dhcp_options_id     = oci_core_vcn.test_vcn.default_dhcp_options_id
}

############ Security List ##########
resource "oci_core_security_list" "tf_sl_web" {
  display_name   = "tf_handson_sl"
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.tf_handson_vcn

  egress_security_rules = [{
    protocol    = "all"
    destination = "0.0.0.0/0"
  }]

  ingress_security_rules = [{
    tcp_options {
      "max" = 22
      "min" = 22
    }

    protocol = "6"
    source   = "0.0.0.0/0"
  },
    {
      tcp_options {
        "max" = 80
        "min" = 80
      }

      protocol = "6"
      source   = "0.0.0.0/0"
    },
    {
      tcp_options {
        "max" = 443
        "min" = 443
      }

      protocol = "6"
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 0
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 3
        "code" = 4
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
    {
      icmp_options {
        "type" = 8
      }

      protocol = 1
      source   = "0.0.0.0/0"
    },
  ]
}






# 2. Create VM



# Defines the number of instances to deploy
variable "num_instances" {
  default = "1"
}



variable "instance_shape" {
  default = "VM.Standard2.1"
}

variable "instance_image_ocid" {
  type = "map"

  default = {
    # See https://docs.us-phoenix-1.oraclecloud.com/images/
    # Oracle-provided image "Oracle-Linux-7.5-2018.10.16-0"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaaoqj42sokaoh42l76wsyhn3k2beuntrh5maj3gmgmzeyr55zzrwwa"

    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaageeenzyuxgia726xur4ztaoxbxyjlxogdhreu3ngfj2gji3bayda"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaitzn6tdyjer7jl34h2ujz74jwy5nkbukbh55ekp6oyzwrtfa4zma"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa32voyikkkzfxyo4xbdmadc2dmvorfxxgdhpnk6dw64fa3l4jh7wa"
    ap-seoul-1     = "ocid1.image.oc1.ap-seoul-1.aaaaaaaai233ko3wxveyibsjf5oew4njzhmk34e42maetaynhbljbvkzyqqa"
  }
}

variable "db_size" {
  default = "50" # size in GBs
}

variable "tag_namespace_description" {
  default = "Just a test"
}

variable "tag_namespace_name" {
  default = "testexamples-tag-namespace"
}

resource "oci_core_instance" "tf_hanson_instance" {
  count               = var.num_instances
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "TestInstance${count.index}"
  shape               = var.instance_shape

  create_vnic_details {
    subnet_id        = oci_core_subnet.tf_subnet.id
    display_name     = "Primaryvnic"
    assign_public_ip = true
    hostname_label   = "tfexampleinstance${count.index}"
  }

  source_details {
    source_type = "image"
    source_id   = var.instance_image_ocid[var.region]

    # Apply this to set the size of the boot volume that's created for this instance.
    # Otherwise, the default boot volume size of the image is used.
    # This should only be specified when source_type is set to "image".
    #boot_volume_size_in_gbs = "60"
  }

  # Apply the following flag only if you wish to preserve the attached boot volume upon destroying this instance
  # Setting this and destroying the instance will result in a boot volume that should be managed outside of this config.
  # When changing this value, make sure to run 'terraform apply' so that it takes effect before the resource is destroyed.
  #preserve_boot_volume = true

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(file("./userdata/bootstrap"))
  }
  # defined_tags = "${
  #   map(
  #     "${oci_identity_tag_namespace.tag-namespace1.name}.${oci_identity_tag.tag2.name}", "awesome-app-server"
  #   )
  # }"
  # freeform_tags = "${map("freeformkey${count.index}", "freeformvalue${count.index}")}"
  # timeouts {
  #   create = "60m"
  # }
}


output "instance_public_ips" {
  value = [oci_core_instance.test_instance.*.public_ip]
}

# Output the boot volume IDs of the instance
output "boot_volume_ids" {
  value = ["${oci_core_instance.test_instance.*.boot_volume_id}"]
}

# Output all the devices for all instances
output "instance_devices" {
  value = ["${data.oci_core_instance_devices.test_instance_devices.*.devices}"]
}

# Output the chap secret information for ISCSI volume attachments. This can be used to output
# CHAP information for ISCSI volume attachments that have "use_chap" set to true.
#output "IscsiVolumeAttachmentChapUsernames" {
#  value = ["${oci_core_volume_attachment.test_block_attach.*.chap_username}"]
#}
#
#output "IscsiVolumeAttachmentChapSecrets" {
#  value = ["${oci_core_volume_attachment.test_block_attach.*.chap_secret}"]
#}

output "silver_policy_id" {
  value = "${data.oci_core_volume_backup_policies.test_predefined_volume_backup_policies.volume_backup_policies.0.id}"
}

output "attachment_instance_id" {
  value = "${data.oci_core_boot_volume_attachments.test_boot_volume_attachments.*.instance_id}"
}


