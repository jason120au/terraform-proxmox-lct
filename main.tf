terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc4"
    }
  }
}
provider "proxmox" {
    pm_tls_insecure = true
    pm_api_url = "https://proxmoxsiz.jason120au.net/api2/json"
    pm_password = var.proxmox_password
    pm_user = var.proxmox_user
    pm_otp = ""
   
}


resource "proxmox_lxc" "basic" {
  target_node  = "dellt30proxmox"
  hostname     = "vault"
  count        = 1
  ostemplate   = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
  ssh_public_keys = var.ssh_key
  password     =  var.device_password
  unprivileged = true
  vmid         = "200${count.index}"
  # onboot       = true
  start        = true
  

  // Terraform will crash without rootfs defined
  rootfs {
    storage = "local-lvm"
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
    private_key = file("~/.ssh/terraform")
    agent = false
    timeout = "3m"
  } 
provisioner "remote-exec" {
    inline = [
        "apt-get update -y",
        "apt-get install -y sudo",
        "useradd -m jason -s /bin/bash",
        "echo jason:ThoMas879| chpasswd",
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




