# Extract bitLocker recovery keys for mounted volumes
# Also identifies drives that do not have bitLocker enabled

Add-Type -AssemblyName System.Windows.Forms

$data = @()

$bitLockerVolumes = Get-BitLockerVolume

$physicalDisks = Get-PhysicalDisk

# Loop through each physical disk to inspect its partitions
foreach ($disk in $physicalDisks) {
    # Obtain partitions for the current disk
    $partitions = Get-Partition -DiskNumber $disk.DeviceID

    foreach ($partition in $partitions) {
        # Proceed only if the partition has an assigned drive letter
        if ($partition.DriveLetter) {
            # Determine if the partition is BitLocker-protected
            $volume = $bitLockerVolumes | Where-Object { $_.MountPoint -eq $partition.DriveLetter + ":" }

            # If the partition is fully encrypted with bitLocker
            if ($volume -and $volume.VolumeStatus -eq 'FullyEncrypted') {
                # Retrieve the BitLocker recovery key for the volume
                $recoveryKey = $volume.KeyProtector | Where-Object KeyProtectorType -eq 'RecoveryPassword'

                # Create a custom object with disk and recovery key information
                $obj = New-Object PSObject -Property @{
                    DriveSerial = $disk.SerialNumber
                    DriveModel  = $disk.Model
                    RecoveryKey = $recoveryKey.RecoveryPassword
                }

                $data += $obj
            } else {
                Write-Host "Drive $($partition.DriveLetter): is not BitLocker-protected."
            }
        }
    }
}

# Check if the $data array has any entries
if ($data.Count -gt 0) {
    # Create a save file dialog for the user to select the save location
    $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveFileDialog.Filter = "CSV files (.csv)|.csv"
    $saveFileDialog.Title = "Select Location to Save BitLocker Recovery Keys"

    $dialogResult = $saveFileDialog.ShowDialog()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK -and $saveFileDialog.FileName -ne "") {
        $data | Export-Csv -Path $saveFileDialog.FileName -NoTypeInformation
        Write-Host "BitLocker Recovery Keys have been saved to $($saveFileDialog.FileName)"
    } else {
        Write-Host "Operation cancelled or no file was selected for saving."
    }
} else {
    Write-Host "No BitLocker-encrypted drives were found."
}
