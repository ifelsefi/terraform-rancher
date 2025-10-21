#!/bin/bash

#set -x

export ANSIBLE_CONFIG=~/repos/terraform_rancher/eks/ansible/ansible.cfg

update_kubectl () {
echo -e "\n\nUpdating kubeconfig file\n\n"
aws eks update-kubeconfig --kubeconfig ~/.kube/"$eks_cluster" --name "$eks_cluster"

echo -e "\n\nShow nodes in cluster\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" get nodes --show-labels
}

update_kubectl

deploy_autoscaler () {
echo -e "\n\nDelete aws-node daemonset\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" -n default delete daemonset aws-node -n kube-system	

echo -e "\n\nAdd aws cni\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" apply -f autoscaler/aws-k8s-cni.yaml

echo -e "\n\nWaiting for aws-node app\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" rollout status daemonset -n kube-system aws-node --timeout 60s

echo -e "\n\nAdding autoscaler\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" apply -f autoscaler/cluster-autoscaler-autodiscover.yaml
}

deploy_autoscaler

add_extra_iam_role_permissions () {

patch_annotate_autoscaler () {
echo -e "\n\nPatching autoscaler\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'

echo -e "\n\nAnnotating Autoscaler\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" annotate serviceaccount cluster-autoscaler -n kube-system eks.amazonaws.com/role-arn=arn:aws:iam::"{{ iam_role_string }}"
}

patch_annotate_autoscaler
wait_for_autoscaler () {

echo -e "\n\nWaiting for autoscaler\n\n"
kubectl --kubeconfig ~/.kube/"$eks_cluster" rollout status deployment -n kube-system cluster-autoscaler --timeout 60s
}

wait_for_autoscaler
