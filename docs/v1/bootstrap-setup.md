# Setup for the Lithium Infrastructure

If you start from nothing you will start in the "bootstrap" phase. This involves setting up the Proxmox host, defining the infrastructure in Terraform, and then using Ansible to configure the VMs and Kubernetes clusters. 
The bootstrap phase starts with a minimum of 2 physical machines. One will be the Proxmox host and the other will be the management host where you run Terraform and Ansible.

## Installing Proxmox VE
1. Download the Proxmox VE ISO from the official website: https://www.proxmox.com/en/downloads/proxmox-virtual-environment/iso
2. Create a bootable USB drive with the Proxmox ISO using a tool like Rufus (Windows) or balenaEtcher (Linux/Mac).
3. Insert the USB drive into the machine you want to use as the Proxmox host. 
4. Start the machine and go to the BIOS/UEFI settings and change the boot order to boot from the USB drive first.
5. Follow the on-screen instructions to install Proxmox VE on the machine. I recommend using the terminal UI installation mode. (So you don't need an extra mouse)
   1. Accept the EULA
   2. Select the target hard drive for installation
   3. Configure the country, time zone, and keyboard layout
   4. Set the root password and email address
   5. Configure the network settings (IP address, netmask, gateway, and DNS)
      1. Default IP address is 192.168.1.25/24
      2. Gateway & DNS should be set automatically to your network's gateway
   6. Check the automatic reboot option and start the installation
6. Try logging in to the Proxmox web UI from another machine using the IP address you configured (e.g. http://192.168.1.25:8006/).
7. Reboot the proxmox host, go the BIOS/UEFI settings again and change the boot order back to boot from the hard drive first.
8. Log in on the command line interface of the Proxmox host
9. Remove the proxmox enterprise sources
   1. Edit the file ```/etc/apt/sources.list.d/pve-enterprise.source``` and ```/etc/apt/sources.list.d/ceph.source```
   2. On the bottom of the block in each file add the line ```Enabled: no```
   3. Add a new file: ```/etc/apt/sources.list.d/pve-no-subscription.source```
   4. Edit the file and add the following content:
    ```
    Types: deb
    URIs: http://download.proxmox.com/debian/pve
    Suites: bookworm
    Components: pve-no-subscription
    Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
    ```
10. Run ```apt update && apt full-upgrade```
11. Create a new user for terraform via the WebUI
    1. Go to Datacenter → Permissions → Users → Add
    2. Set the user ID to "terraform", select "pam" as the realm, and set a password
    3. Click "Add"
12. Assign the "terraform" user to the "PVEAdmin" role
    1. Go to Datacenter → Permissions → Add -> User Permission
    2. Select the "terraform" user, set the path to "/" and select the "Administrator" role
    3. Click "Add"
13. Create an API token for the terraform user
    1. Go to Datacenter → Permissions → API Tokens → Add
    2. Set the token ID to "terraform-access"
    3. Click "Add"
    4. Copy the generated token value, you will need it for the Terraform configuration
14. Configure the local storage to allow snippets
    1. Go to Datacenter → Storage → local → Edit
    2. Check the "Snippets" content type and click "Save"

## Setting Up the Management Host
The management host is an external machine which is only needed in the bootstrap phase for the initial setup. This can be a laptop or raspberry pi. 

1. Connect to your management host (direct or via SSH). In my case this is rasp-mgmt-001.
2. Install the necessary tools:
   1. Terraform: https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
   2. Ansible: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html
      1. Or just run ```apt install ansible -y``` on Debian-based systems
   3. Git: https://git-scm.com/downloads
3. Clone the following repository: https://github.com/FlorianGubler-Lithium/lithium-infra
4. Configure your local SSH agent to allow connecting to the proxmox host

## Bootstrapping the Infrastructure
### Terraform Initialization
Terraform handles all the VM provisioning and network configuration on the Proxmox host. The Terraform configuration is located in the ```terraform``` directory of the repository.

1. Navigate to the terraform directory and run ```terraform init``` to initialize the Terraform configuration.
2. Create a file named ```terraform.tfvars``` in the terraform directory with the following content, replacing the values with your Proxmox API credentials and template IDs:
   ```
   pm_api_url            = "http://192.168.1.25:8006/api2/json"
   pm_api_token_secret   = "<Generated API Token Value>"
   pm_node               = "prx-001"
   vm_password           = "<Initial VM Password>"
   debian_iso            = "local:iso/<DEBIAN ISO FILENAME>.iso"
   dns_servers           = ["1.1.1.1", "1.0.0.1"]
   ```
### Ansible Initialization
Ansible is used for configuring the VMs after they are provisioned by Terraform. The Ansible configurations are located in the ```ansible``` directory of the repository.

