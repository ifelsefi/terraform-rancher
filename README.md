
Terraforming Rancher
===============


In this role you will find configs for creating Downstream EKS Clusters to be used for Rancher.


Requirements
------------

You should have access to a service account in Rancher and created keys within Rancher using this account.  Rancher must also have access to AWS to create EKS cluster creation.  If there are issues with this step then [contact the author](mailto:quackmaster@protonmail.com).  For testing these should be [stored in your ~/.bash_profile](https://blog.gruntwork.io/a-comprehensive-guide-to-managing-secrets-in-your-terraform-code-1d586955ace1) then later a secrets management service like Hashicorp Vault.

Terraform [should be installed](https://learn.hashicorp.com/tutorials/terraform/install-cli) on your box.


TODO
--------------
Refactor for newer versions of Terraform and Rancher

Integrate with Vault


Syntax 
--------------

To deploy a downstream cluster in HDC first run `terraform init` if you have never done this previously.

Ensure you are in the top level directory not the eks subdirectory:


```

quackmaster@node[~/repos/terraform_rancher]$ pwd
~/repos/terraform_rancher

quackmaster@node[~/repos/terraform_rancher]$ terraform init

Initializing the backend...

Initializing provider plugins...
- Finding rancher/rancher2 versions matching "1.16.0"...
- Installing rancher/rancher2 v1.16.0...
- Installed rancher/rancher2 v1.16.0 (signed by a HashiCorp partner, key ID ABC123)

Terraform has been successfully initialized!

```


Once `init` has been completed you should run `terraform plan` to ensure correct cluster config.  

If things look right then create the cluster:


quackmaster@node[~/repos/terraform_rancher]$ **TF_VAR_rke_cluster_name=git-rich-or-die-trying terraform apply -auto-approve**.


```
Plan: 1 to add, 0 to change, 0 to destroy.
rancher2_cluster.cluster: Creating...
rancher2_cluster.cluster: Creation complete after 3s [id=c-12345]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

```

Wait about 10 minutes for deployment then join to upstream Rancher cluster.
