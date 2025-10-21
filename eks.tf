############### ------------------------- VARIABLES BEGIN ------------------------- ##############

# Rancher credential vars
variable "rke_api_url" {
  description = "The URL for Rancher's API access"
  type = string
  sensitive = false
}
variable "rke_access_key" {
  description = "The access key used in Rancher for auth"
  type = string
  sensitive = true
}
variable "rke_secret_key" {
  description = "The secret key used in Rancher for auth"
  type = string
  sensitive = true
}

# EKS credential vars
#
variable "eks_iam_user" {
  description = "The IAM account used by Rancher for EKS auth"
  type = string
  sensitive = true
}
variable "eks_access_key" {
  description = "The access key used by Rancher for EKS auth"
  type = string
  sensitive = true
}
variable "eks_secret_key" {
  description = "The secret key used by Rancher for EKS auth"
  type = string
  sensitive = true
}

# Ansible vault var
variable "ansible_vault" {
  description = "Ansible vault password"
  type = string
  sensitive = true
}

# Below we define cluster name so we can export at command line
variable "eks_cluster_name" {
  description = "The name of cluster you will deploy"
  type = string
  sensitive = false
}

variable "eks_cluster_owner" {
  description = "The user who deployed the cluster"
  type = string
  sensitive = false
}

locals { 
  eks_cluster_name_lt_r5b = "${var.eks_cluster_name}_lt_r5b"
  eks_cluster_name_lt_t3 = "${var.eks_cluster_name}_lt_t3"
}

data "cloudinit_config" "ec2_user_data" {
  gzip = false
  base64_encode = true
  part {
    content_type = "text/x-shellscript"
    content = <<EOT
#!/bin/bash
set -ex
sudo yum-config-manager --disable neuron
touch /tmp/outfile
sudo amazon-linux-extras install ansible2 -y 2>&1 | tee /tmp/outfile && sudo yum install -y traceroute bind-utils git 2>&1 | tee /tmp/outfile
cd /tmp
git clone -c http.sslVerify=false https://github.com/ifelsefi/terraform-rancher.git 2>&1 | tee /tmp/outfile
cd /tmp/terraform-rancher/downstream/eks
echo '${var.ansible_vault}' > /tmp/vault.yml 2>&1 | tee /tmp/outfile
export eks_cluster_owner=${var.eks_cluster_owner} && export eks_cluster=${var.eks_cluster_name} && ansible-playbook ansible/eks_node_pull_localhost.yml --vault-password-file /tmp/vault.yml 2>&1 | tee /tmp/outfile
rm -rf /tmp/terraform-rancher
rm -rf /tmp/vault.yml
EOT
   }
}
# var used for backups in s3 bucket
variable "tf_state_bucket" {
  description = "bucket used for storing tfstate backups"
  type = string
  sensitive = false
}

# Rancher version used with 'terraform init'
terraform {
  backend "s3" {
    bucket = "bucket"  
    region = "us-east-2"
    key = "eks/eks.tfstate"
  }
  required_providers {
    cloudinit = {
      source = "hashicorp/cloudinit"
      version = "~> 2.2.0"
    }
    rancher2 = {
      source = "rancher/rancher2"
      version = "~> 1"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }    
  }
}  

provider "aws" {
  region  = "us-east-2"
  access_key = var.eks_access_key
  secret_key = var.eks_secret_key
}

# Define below in your ~/.bash_profile
provider "rancher2" {
  api_url    = var.rke_api_url
  access_key = var.rke_access_key
  secret_key = var.rke_secret_key
}

# Vars passed
resource "rancher2_cloud_credential" "prod" {
  name = "prod"
  description = var.eks_iam_user
  amazonec2_credential_config {
    access_key = var.eks_access_key
    secret_key = var.eks_secret_key 
  }
}

############### ------------------------- VARIABLES END ------------------------- ##############


# Launch template creation

resource "aws_launch_template" "t3" {
  name = local.eks_cluster_name_lt_t3
  ebs_optimized = true
  vpc_security_group_ids = ["sg"]
  user_data = "${data.cloudinit_config.ec2_user_data.rendered}"
  instance_type = "t3.medium"
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = "50"
      iops = "200"
      volume_type = "io2"
    }
  }
  key_name = "eks"
  tags = {
    MaintenanceOwner = "k8s"
    AllocatedOwner = "k8s-admin"
    Name = "eks-ci-cd"
    AllocatedUse = "eks-ci-cd"
    AllocatedStat = "prod"
    ContactEmailDL = "quackmaster@protonmail.com"
  }  
}

# Cluster creation
resource "rancher2_cluster" cluster  {
  name = var.eks_cluster_name
  description = "Terraform EKS cluster"
  eks_config_v2 {
    cloud_credential_id = rancher2_cloud_credential.prod.id
    region = "us-east-2"
    kubernetes_version = "1.20"
    logging_types = ["audit", "api", "scheduler", "controllerManager", "authenticator"]
    node_groups {
      desired_size = "2"
      max_size = "2"
      min_size = "2"
      disk_size = "50"
      name = "${var.eks_cluster_name}-t3"
      instance_type = "t3.medium"
      launch_template {
        id = "${aws_launch_template.t3.id}"
        version = "1"
      }   
    }  
    service_role = "aws-eks-prod-eks-service-sr"
    security_groups = ["sg"]
    subnets = ["subnet-abc", "subnet-xyz"]
    private_access = "true"
    public_access = "false"
    tags = {"MaintenanceOwner": "k8s", "AllocatedOwner": "k8s-admin", "Name": "k8s-ci-cd", "AllocatedUse": "k8s-ci-cd", "AllocatedState": "prod", "ContactEmailDL": "quackmaster@protonmail.com"}
  } 
  provisioner "local-exec" {
  command = "sleep 10 && export eks_cluster=${var.eks_cluster_name} && export eks_cluster_owner=${var.eks_cluster_owner} && bash ./configure_eks_cluster.bash"
  }
}
