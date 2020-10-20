# Set variables
    $resourceGroup = "moogtemplatetest"
    $vmName = "SGAZ1SV-VCE01"
    $newAvailSetName = "SGAZ1SV-VCE-AS"
    $trans1NicId = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/networkInterfaces/NIC-SGAZ1SV-VCE01-TRANS1"
    $trans2NicId = "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RG_NAME>/providers/Microsoft.Network/networkInterfaces/NIC-SGAZ1SV-VCE01-TRANS2"

# Get the details of the VM to be moved to the Availability Set
    $originalVM = Get-AzVM `
	   -ResourceGroupName $resourceGroup `
	   -Name $vmName

# Create new availability set if it does not exist
    $availSet = Get-AzAvailabilitySet `
	   -ResourceGroupName $resourceGroup `
	   -Name $newAvailSetName `
	   -ErrorAction Ignore
    if (-Not $availSet) {
    $availSet = New-AzAvailabilitySet `
	   -Location $originalVM.Location `
	   -Name $newAvailSetName `
	   -ResourceGroupName $resourceGroup `
	   -PlatformFaultDomainCount 2 `
	   -PlatformUpdateDomainCount 2 `
	   -Sku Aligned
    }

# Remove the original VM
    Remove-AzVM -ResourceGroupName $resourceGroup -Name $vmName    

# Create the basic configuration for the replacement VM. 
    $newVM = New-AzVMConfig `
	   -VMName $originalVM.Name `
	   -VMSize Standard_DS4_v2 `
	   -AvailabilitySetId $availSet.Id

Set-AzVMOSDisk `
    -VM $newVM -CreateOption Attach `
    -ManagedDiskId $originalVM.StorageProfile.OsDisk.ManagedDisk.Id `
    -Name $originalVM.StorageProfile.OsDisk.Name `
    -Linux

foreach ($nic in $originalVM.NetworkProfile.NetworkInterfaces) {
 if ($nic.Primary -eq "True")
 {
     Add-AzVMNetworkInterface `
        -VM $newVM `
        -Id $nic.Id -Primary
        }
        else
        {
          Add-AzVMNetworkInterface `
          -VM $newVM `
          -Id $nic.Id
                 }
   }

Add-AzVMNetworkInterface -VM $newVM -Id $trans1NicId

Add-AzVMNetworkInterface -VM $newVM -Id $trans2NicId

Set-AzVMPlan -VM $newVM -Publisher "velocloud" -Product "velocloud-virtual-edge-3x" -Name "velocloud-virtual-edge-3x"

New-AzVM `
    -ResourceGroupName $resourceGroup `
    -Location $originalVM.Location `
    -VM $newVM `
    -DisableBginfoExtension