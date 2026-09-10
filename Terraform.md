# Set up proxmox user, permissions and provider for Terraform.

### Create Terraform role and add permissions
Based on exact needs this should be changed.
``` c#
pveum role modify TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.PowerMgmt SDN.Use"
```

### Create and set password for Terraform user
Save the password somowhere you will need it again
``` c#
pveum user add terraform-prov@pve --password <TerraformUserPassword>
```

### Add the Terraform role to the Terraform user

``` c#
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

# Create Terraform proxmox provider
Steps to create the Terraform proxmox provider.

### Setup enviorment variables in Terraform for proxmox
Saves the username and password to enviorment variables make sure to add this file to .gitignore
``` c#
export PM_USER="terraform-prov@pve"
export PM_PASS="TerraformUserPassword"
```

### Create main.tf
This setups the Terraform provider for proxmox allowing Terraform to create destroy and edit VM's in proxmox.
``` c#
terraform {
  required_providers {
    proxmox = {
      source  = "Terraform-for-Proxmox/proxmox"
    }
  }
}
```

### Enter the right directory and initialize terraform
``` c#
teraform init
```
DD
### From the init add version flag to main.tf
The init will give you back the current version number for Terraform-for-proxmox. It is smart to add this to your main.tf file so the version doesn't change and destroy your setup.
``` c#
terraform {
  required_providers {
    proxmox = {
      source  = "Terraform-for-Proxmox/proxmox"
      version = "version-number"
    }
  }
}
```

### Add proxmox provider to main.tf
This is what finally lets Terraform talk to the provider we created. After this you can setup your VM's and such
``` c#
provider "proxmox" {
  pm_api_url = "https://proxmox.server.url/api2/json"
}
```

