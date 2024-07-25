### Réservations DHCP à partir d’un fichier CSV ###

# Import du fichier CSV
$CSVData = Import-CSV -Path "C:\Reservations.csv"

# Parcours des lignes du fichier CSV
foreach ($row in $CSVData) {
    # Récupération des informations de chaque réservation
    $username = $row.Username
    $macAddress = $row.MacAddress
    $ipAddress = $row.IPAddress

    # Création de la réservation DHCP
    try {
        Add-DhcpServerv4Reservation -ScopeId "10.0.0.0" -IPAddress $ipAddress -ClientId $macAddress -Description $username -ComputerName "YourDHCPServer"
        Write-Output "Reservation added for $username"
    } catch {
        Write-Error "Failed to add reservation for $username: $_"
    }
}

# format du fichier CSV
Username,MacAddress,IPAddress
user1,00-14-22-01-23-45,10.0.0.2
user2,00-14-22-01-23-46,10.0.0.3
user3,00-14-22-01-23-47,10.0.0.4

### Réinitialisation des réservations DHCP en appliquant un filtrage par l’adresse MAC ###

$mac = Read-Host 'Enter MAC address'

$server = 'yourdhcpserver'

$reservation = Get-DhcpServerv4Scope -ComputerName $server |
               Get-DhcpServerv4Reservation -ComputerName $server |
               Where-Object { $_.ClientId -eq $mac }

if ($reservation) {
  $reservation | Remove-DhcpServerv4Reservation -ComputerName $server
} else {
  "$mac not found."
}

# en fonction du format de l'adresse MAC : $mac = $mac -replace ':', '-'

### Réinitialisation des réservations DHCP en appliquant un filtrage par plages d’adresses IP ###

$server = 'yourdhcpserver'

$reservations = Get-DhcpServerv4Scope -ComputerName $server |
                Get-DhcpServerv4Reservation -ComputerName $server |
                Where-Object { $_.IPAddress -notlike "192.168.1.*" -and $_.IPAddress -notlike "192.168.2.*" -and $_.IPAddress -notlike "192.168.3.*" }

if ($reservations) {
  $reservations | Remove-DhcpServerv4Reservation -ComputerName $server
  Write-Output "All non-server reservations removed."
} else {
  Write-Output "No non-server reservations found."
}

### Suppression de toutes les réservations DHCP d’une portée ###

Get-DhcpServerv4Reservation -ComputerName "YourDHCPServer" -ScopeId "10.0.0.0" | Remove-DhcpServerv4Reservation
