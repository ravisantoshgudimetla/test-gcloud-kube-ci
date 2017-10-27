master_uuid=$(uuid)
node_uuid=$(uuid)
kube_version=1.7.6


create_cluster() {
	gcloud compute instances create descheduler-$master_uuid --image="ubuntu-1704-zesty-v20171011" --image-project="ubuntu-os-cloud" --zone=us-east1-b
        echo "gcloud compute instances delete descheduler-$master_uuid --quiet" > delete_cluster.sh
        gcloud compute instances create descheduler-$node_uuid --image="ubuntu-1704-zesty-v20171011" --image-project="ubuntu-os-cloud" --zone=us-east1-b
	echo "gcloud compute instances delete descheduler-$node_uuid --quiet" >> delete_cluster.sh
        chmod 755 delete_cluster.sh
}


generate_kubeadm_instance_files() {
	# TODO: Check if they have come up. awk $6 contains the state(RUNNING or not).
	master_public_ip=$(gcloud compute instances list | grep $master_uuid|awk '{print $5}')
	node_public_ip=$(gcloud compute instances list | grep $node_uuid|awk '{print $5}')
	echo "kubeadm init --kubernetes-version=${kube_version} --apiserver-advertise-address=${master_public_ip}" --skip-preflight-checks> kubeadm_install.sh
}


transfer_install_files() {
	gcloud compute copy-files  kubeadm_preinstall.sh descheduler-$master_uuid:/tmp --zone=us-east1-b
	gcloud compute copy-files kubeadm_install.sh descheduler-$master_uuid:/tmp --zone=us-east1-b
	gcloud compute copy-files  kubeadm_preinstall.sh descheduler-$node_uuid:/tmp --zone=us-east1-b
}


install_kube() {
	# Docker installation.
	gcloud compute ssh descheduler-$master_uuid --command "sudo apt-get update; sudo apt-get install -y docker.io" --zone=us-east1-b
	gcloud compute ssh descheduler-$node_uuid --command "sudo apt-get update; sudo apt-get install -y docker.io" --zone=us-east1-b
	# kubeadm installation.
	# 1. Transfer files to master, nodes.
	transfer_install_files
	# 2. Install kubeadm.
	#TODO: Add rm /tmp/kubeadm_install.sh
	gcloud compute ssh descheduler-$master_uuid --command "sudo chmod 755 /tmp/kubeadm_preinstall.sh; sudo /tmp/kubeadm_preinstall.sh" --zone=us-east1-b	
	kubeadm_join_command=$(gcloud compute ssh descheduler-$master_uuid --command "sudo chmod 755 /tmp/kubeadm_install.sh; sudo /tmp/kubeadm_install.sh" --zone=us-east1-b|grep 'kubeadm join')
	# Postinstall on master, need to add a network plugin for kube-dns to come to running state.
	gcloud compute ssh descheduler-$master_uuid --command "sudo kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml --kubeconfig /etc/kubernetes/admin.conf" --zone=us-east1-b
	# Copy this kubeadm_join_command to every node.
	echo $kubeadm_join_command > kubeadm_join.sh
	gcloud compute ssh descheduler-$node_uuid --command "sudo chmod 755 /tmp/kubeadm_preinstall.sh; sudo /tmp/kubeadm_preinstall.sh" --zone=us-east1-b
	gcloud compute copy-files kubeadm_join.sh descheduler-$node_uuid:/tmp --zone=us-east1-b
	gcloud compute ssh descheduler-$node_uuid --command "sudo chmod 755 /tmp/kubeadm_join.sh; sudo /tmp/kubeadm_join.sh" --zone=us-east1-b

}


create_cluster

generate_kubeadm_instance_files

#transfer_install_files()

install_kube
