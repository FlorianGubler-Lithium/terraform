locals {
  deployment_vms = {
    "kube-dev-master-001" = {
      vm_id                       = 1001
      vm_ci_userdata_file_path    = "vm-configs/deployments/cloud-init/kube-dev-master-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-dev-master-001/network.yaml.tftpl"
      vm_memory                   = 4096
      vm_cpu_cores                = 2
      vm_disk_size                = 20
      vm_network_devices = [
        {
          bridge = "dev"
          ip     = "10.10.0.101"
        }
      ]
      vm_groups = ["dev", "k8s", "k8s_master"]
    },
    "kube-dev-worker-001" = {
      vm_id                       = 1002
      vm_ci_userdata_file_path    = "vm-configs/deployments/cloud-init/kube-dev-worker-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-dev-worker-001/network.yaml.tftpl"
      vm_memory                   = 4096
      vm_cpu_cores                = 2
      vm_disk_size                = 20
      vm_network_devices = [
        {
          bridge = "dev"
          ip     = "10.10.0.102"
        }
      ]
      vm_groups = ["dev", "k8s", "k8s_worker"]
    },
    "kube-prod-master-001" = {
      vm_id     = 2001
      vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-master-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-master-001/network.yaml.tftpl"
      vm_memory = 4096
      vm_cpu_cores = 2
      vm_disk_size = 20
      vm_network_devices = [
        {
          bridge = "prod"
          ip     = "10.20.0.201"
        }
      ]
      vm_groups = ["prod", "k8s", "k8s_master"]
    },
    "kube-prod-worker-001" = {
      vm_id     = 2002
      vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-worker-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/kube-prod-worker-001/network.yaml.tftpl"
      vm_memory = 4096
      vm_cpu_cores = 2
      vm_disk_size = 20
      vm_network_devices = [
        {
          bridge = "prod"
          ip     = "10.20.0.202"
        }
      ]
      vm_groups = ["prod", "k8s", "k8s_worker"]
    }
    "mgmt-dev-001" = {
      vm_id     = 1003
      vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/mgmt-dev-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/mgmt-dev-001/network.yaml.tftpl"
      vm_memory = 4096
      vm_cpu_cores = 2
      vm_disk_size = 20
      vm_network_devices = [
        {
          bridge = "dev"
          ip     = "10.10.0.100"
        }
      ]
      vm_groups = ["dev", "mgmt"]
    },
    "mgmg-prod-001" = {
      vm_id     = 2003
      vm_ci_userdata_file_path = "vm-configs/deployments/cloud-init/mgmt-prod-001/userdata.yaml.tftpl"
      vm_ci_networkdata_file_path = "vm-configs/deployments/cloud-init/mgmt-prod-001/network.yaml.tftpl"
      vm_memory = 4096
      vm_cpu_cores = 2
      vm_disk_size = 20
      vm_network_devices = [
        {
          bridge = "prod"
          ip     = "10.20.0.200"
        }
      ]
      vm_groups = ["prod", "mgmt"]
    }
  }
}