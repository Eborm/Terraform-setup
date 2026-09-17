# Updating the proxmox module
There are a few simple things that need to be adjusted in the proxmox module to make it production ready. Such as having ip reservations based on mac-addersses.

### Adding in the extra variables to the control-nodes
There are 2 extra variables added to improve the reliabilty to build the cluster.

Thus you replace
``` c#
    talos_control_node = {
        "cp-01" = {
            target_node = "node-1" #replace with the target node 
        }
    }
```

With 
```
    talos_control_node = {
        "cp-01" = {
            target_node = "node-1" #replace with the target node 
            mac_address = "Your reserved mac-address"
            ip_address  = "The ip related to the mac-address reservation"
        }
    }
```

That is all you need o do to update your proxmox module ready for to build your talos cluster.