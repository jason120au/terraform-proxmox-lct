variable "proxmox_user" {
  description = "Proxmox API user"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

variable "ssh_key" {
  description = "SSH public key for authentication"
  type        = string
}

variable "ssh_private_key" {
  description = "Path to SSH private key file for authentication"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "device_password" {
  description = "Password for the LXC container"
  type        = string
  sensitive   = true
}

variable "lxc_hostname" {
  description = "Hostname for the LXC container"
  type        = string
  default     = "vault"
}

variable "lxc_target_node" {
  description = "Target Proxmox node for the LXC container"
  type        = string
  default     = "minisforum"
}

variable "vmid" {
  description = "VM ID for the LXC container"
  type        = number
  default     = 0
}

terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.2-rc07"
    }
  }
}
provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://proxmoxsiz.jason120au.net/api2/json"
    pm_api_token_id = var.proxmox_user
    pm_api_token_secret = var.proxmox_password
    pm_user = var.proxmox_user
    pm_otp = ""
   
}


resource "proxmox_lxc" "basic" {
  target_node  = var.lxc_target_node
  hostname     = "test-lxctc"
  count        = 1
  cores        = 2
  ostemplate   = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  ssh_public_keys = var.ssh_key
  password     =  var.device_password
  unprivileged = true
  # onboot       = true
  start        = true


  // Terraform will crash without rootfs defined
  rootfs {
    storage = "lvm-min"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  
  connection {
    host = "${self.hostname}.jasoncorp.lan"
    user = "root"
    private_key = file(pathexpand(var.ssh_private_key))
    agent = false
    timeout = "3m"
  } 
provisioner "remote-exec" {
    inline = [
        "apt-get update -y",
        "apt-get install -y sudo",
        "useradd -m jason -s /bin/bash",
        "echo jason:${var.device_password}| chpasswd",
        "usermod -aG sudo jason",
        "mkdir /home/jason/.ssh",
        "chmod 700 /home/jason/.ssh",
        "echo ${var.ssh_key} >> /home/jason/.ssh/authorized_keys",
        "chmod 600 /home/jason/.ssh/authorized_keys",
        "chown -R jason:jason /home/jason/.ssh",
        "echo 'Provisioned Jason on ${self.hostname}'",
   ]
    
  }
   provisioner "file" {
    content     = "template used: ${self.ostemplate}"
    destination = "/tmp/file.log"
  }
 
}
resource "proxmox_lxc" "basic2" {
  target_node  = var.lxc_target_node
  hostname     =  "testlxctc"
  count        = 1
  cores        = 4
  ostemplate   = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
  ssh_public_keys = var.ssh_key
  password     =  var.device_password
  unprivileged = true
  # onboot       = true
  start        = true


  // Terraform will crash without rootfs defined
  rootfs {
    storage = "lvm-min"
    size    = "8G"
  }

  network {
    name   = "eth0"
    bridge = "vmbr0"
    ip     = "dhcp"
  }

  
  connection {
    host = "${self.hostname}.jasoncorp.lan"
    user = "root"
    private_key = file(pathexpand(var.ssh_private_key))
    agent = false
    timeout = "3m"
  } 
provisioner "remote-exec" {
    inline = [
        "apt-get update -y",
        "apt-get install -y sudo",
        "useradd -m jason -s /bin/bash",
        "echo jason:${var.device_password}| chpasswd",
        "usermod -aG sudo jason",
        "mkdir /home/jason/.ssh",
        "chmod 700 /home/jason/.ssh",
        "echo ${var.ssh_key} >> /home/jason/.ssh/authorized_keys",
        "chmod 600 /home/jason/.ssh/authorized_keys",
        "chown -R jason:jason /home/jason/.ssh",
        "echo 'Provisioned Jason on ${self.hostname}'",
   ]
    
  }
   provisioner "file" {
    content     = "template used: ${self.ostemplate}"
    destination = "/tmp/file.log"
  }
 
}

resource "local_file" "ansible" {
      content  = "template used: ${proxmox_lxc.basic.0.ostemplate}"
      filename = "/tmp/foo.bar"
    }


// output details
output "vm_ids" {
  value = [for vm in proxmox_lxc.basic : vm.vmid]
}
output "vm_names" {
  value = [for vm in proxmox_lxc.basic : vm.hostname]
}
output "vm_ips" {
  value = [for vm in proxmox_lxc.basic : vm.network[0].ip]
  description = "IP addresses of the LXC containers"
}
resource "local_file" "ansible_inventory" {
  content = "${join("\n", [for vm in proxmox_lxc.basic : "${vm.hostname} ansible_host=${vm.hostname}"]) }"
  filename = "inventory.ini"
}

# output "vm_names" {
#   value = [for vm in proxmox_vm_qemu.vm : vm.name]
# }




