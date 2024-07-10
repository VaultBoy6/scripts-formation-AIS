#####################
### script AD P9 ###
#####################

try {
    # Création de l'utilisateur "ansible" en tant qu'Admin du domaine
    New-ADUser -Name "ansible" `
               -GivenName "Ansible" `
               -Surname "AdminAnsible" `
               -SamAccountName "ansible" `
               -AccountPassword (ConvertTo-SecureString -AsPlainText "P@ssw0rd12345" -Force) `
               -Enabled $true `
               -PassThru
    # Ajouter l'utilisateur "ansible" au groupe "Admins du domaine"
    Add-ADGroupMember -Identity "Admins du domaine" -Members "ansible"

    # Création du dossier "Utilisateurs" dans "Documents"
    $documentsFolderPath = "C:\Users\Administrateur\Documents\Utilisateurs"
    New-Item -Path $documentsFolderPath -ItemType Directory -Force
    # Partage du dossier sur le réseau
    New-SmbShare -Name "Utilisateurs" -Path $documentsFolderPath -FullAccess "Administrateur" -ReadAccess "Utilisateurs authentifiés"

    # Création du dossier "Departements" dans "Documents"
    $departmentsFolderPath = "C:\Users\Administrateur\Documents\Departements"
    New-Item -Path $departmentsFolderPath -ItemType Directory -Force
    # Partage du dossier sur le réseau
    New-SmbShare -Name "Departements" -Path $departmentsFolderPath -FullAccess "Administrateur" -ReadAccess "Utilisateurs authentifiés"
    # Définition des noms des départements
    $departments = @("Audio", "Administration", "Dev", "Graphisme", "IT", "Prodcom", "Testing")
    # Boucle qui va parcourir chaque département
    foreach ($department in $departments) {
    # Rappel variable dans la boucle: le chemin du dossier "Utilisateurs"
    $departmentsFolderPath = "C:\Users\Administrateur\Documents\Departements"
    # Création du dossier pour le département
    $departmentFolderPath = "$departmentsFolderPath\$department"
    New-Item -Path $departmentFolderPath -ItemType Directory -Force
    }

    # Import du fichier CSV
    $CSVFile = "\\vmware-host\Shared Folders\VMware\Utilisateurs.csv"
    $CSVData = Import-CSV -Path $CSVFile -Delimiter ";" -Encoding UTF8

    # Création de l'OU parente "DOMAINE BARZINI" si elle n'existe pas déjà
    $ParentOU = "DOMAINE BARZINI"
    $ParentOUPath = "OU=$ParentOU,DC=BARZINI,DC=COM"
    if (-not (Get-ADOrganizationalUnit -Filter {Name -eq $ParentOU})) {
        New-ADOrganizationalUnit -Name $ParentOU -Path "DC=BARZINI,DC=COM"
        Write-Host "Création de l'OU parente : $ParentOU"
    }

    # Création des OUs dans l'OU parente
    $OUs = "OU_Administration", "OU_Prodcom", "OU_Dev", "OU_Graphisme", "OU_Audio", "OU_Testing", "OU_IT", "OU_Directeurs"
    foreach ($OU in $OUs) {
        $OUPath = "OU=$OU,$ParentOUPath"
        if (-not (Get-ADOrganizationalUnit -Filter {Name -eq $OU})) {
            New-ADOrganizationalUnit -Name $OU -Path $ParentOUPath
            Write-Host "Création de l'OU : $OU dans $ParentOU"            
            # Création du groupe correspondant dans l'OU
            $Groupe = "GG_$OU"
            $GroupePath = "OU=$OU,$ParentOUPath"
            if (-not (Get-ADGroup -Filter {Name -eq $Groupe})) {
                New-ADGroup -Name $Groupe -Path $GroupePath -GroupScope Global -GroupCategory Security
                Write-Host "Création du groupe $Groupe dans l'OU $OU"
            }
        }
    }

    # Boucle pour la création des utilisateurs
    foreach ($Utilisateur in $CSVData) {
        $UtilisateurPrenom = $Utilisateur.Prenom
        $UtilisateurNom = $Utilisateur.Nom
        $UtilisateurLogin = $UtilisateurPrenom[0] + ".$UtilisateurNom".ToLower()
        $UtilisateurEmail = "$UtilisateurLogin@barzini.com".ToLower()
        $UtilisateurPoste = $Utilisateur.Poste
        $UtilisateurMotDePasse = "P@ssw0rd12345"
        $Departement = "OU_" + $Utilisateur.Departement  # Ajout du préfixe "OU_"

        # Récupération du chemin de l'OU correspondante
        $OUPath = "OU=$Departement,$ParentOUPath"   

        # Vérification de la présence sinon création de l'utilisateur dans l'AD
        if (Get-ADUser -Filter {SamAccountName -eq $UtilisateurLogin}) {
            Write-Warning "L'identifiant $UtilisateurLogin existe déjà dans l'AD"
        }
        else {
            New-ADUser -Name "$UtilisateurNom $UtilisateurPrenom" `
                    -DisplayName "$UtilisateurNom $UtilisateurPrenom" `
                    -GivenName $UtilisateurPrenom `
                    -Surname $UtilisateurNom `
                    -SamAccountName $UtilisateurLogin `
                    -UserPrincipalName "$UtilisateurLogin@barzini.com" `
                    -EmailAddress $UtilisateurEmail `
                    -Title $UtilisateurFonction `
                    -Description $UtilisateurPoste `
                    -Path $OUPath `
                    -AccountPassword (ConvertTo-SecureString $UtilisateurMotDePasse -AsPlainText -Force) `
                    -ChangePasswordAtLogon $true `
                    -Enabled $true `
                    -PassThru

            # Rappel variable: le chemin du dossier "Utilisateurs"
            $documentsFolderPath = "C:\Users\Administrateur\Documents\Utilisateurs"
            # Créer le dossier pour l'utilisateur
            $userFolderPath = "$documentsFolderPath\$UtilisateurLogin"
            New-Item -Path $userFolderPath -ItemType Directory -Force
            # Définir les permissions NTFS
            icacls $userFolderPath /grant ($UtilisateurLogin + ":(M)")

            Write-Host "Partage du dossier : $userFolderPath"
            Write-Host "Création de l'utilisateur : $UtilisateurLogin ($UtilisateurNom $UtilisateurPrenom)"

            # Désactivation du compte si l'utilisateur est Offline dans le CSV
            if ($Utilisateur.Statut -eq "Offline") {
                Disable-ADAccount -Identity $UtilisateurLogin
                Write-Host "Le compte de l'utilisateur $UtilisateurLogin a été désactivé car l'utilisateur est Offline"
            }

            # Vérification et ajout de l'utilisateur au groupe correspondant à son département
            $Groupe = "GG_$Departement"
            $GroupePath = "OU=$Departement,$ParentOUPath"
            if (-not (Get-ADGroupMember -Identity $Groupe -Recursive | Where-Object { $_.SamAccountName -eq $UtilisateurLogin })) {
                Add-ADGroupMember -Identity $Groupe -Members $UtilisateurLogin
                Write-Host "Ajout de l'utilisateur $UtilisateurLogin au groupe $Groupe"
            }

            # Ajout des directeurs au groupe GG_OU_Directeurs
            $Groupe2 = "GG_OU_Directeurs"
            $Groupe2Path = "OU=Directeurs,$ParentOUPath"
            # Création du groupe GG_OU_Directeurs s'il n'existe pas déjà
            if (-not (Get-ADGroup -Identity $Groupe2)) {
                New-ADGroup -Name $Groupe2 -GroupScope Global -Path $Groupe2Path
            }
            if ($Utilisateur.Poste.Contains("Directeur") -or $Utilisateur.Poste.Contains("Directrice")) {
                Add-ADGroupMember -Identity $Groupe2 -Members $UtilisateurLogin
                Write-Host "Ajout de la directrice générale $($UtilisateurLogin) au groupe $GG_OU_Directeurs"
            }
        }

        # Création des groupes de domaine local (RO + RW)
        $GDL_RW = "GDL_RW_$Departement"
        $GDL_RO = "GDL_RO_$Departement"     
        if (-not (Get-ADGroup -Filter {Name -eq $GDL_RW})) {
            New-ADGroup -Name $GDL_RW -GroupScope DomainLocal -GroupCategory Security -Path $GroupePath
            Write-Host "Création du groupe de domaine local RW : $GDL_RW dans l'OU $Departement"
        }
        if (-not (Get-ADGroup -Filter {Name -eq $GDL_RO})) {
            New-ADGroup -Name $GDL_RO -GroupScope DomainLocal -GroupCategory Security -Path $GroupePath
            Write-Host "Création du groupe de domaine local RO : $GDL_RO dans l'OU $Departement"
        }
    }

    # Création de la PSO
    New-ADFineGrainedPasswordPolicy -Name "PSOBarzini" `
        -Precedence 1 `
        -ComplexityEnabled $true `
        -ReversibleEncryptionEnabled $false `
        -PasswordHistoryCount 24 `
        -MinPasswordLength 12 `
        -LockoutThreshold 5 `
        -LockoutObservationWindow (New-TimeSpan -Minutes 30) `
        -MaxPasswordAge (New-TimeSpan -Days 120) `
        -MinPasswordAge (New-TimeSpan -Hours 1)

    Write-Host "PSOBarzini a été créé avec succès."    

    # Application de la PSO à l'utilisateur
    Add-ADFineGrainedPasswordPolicySubject PSOBarzini -Subjects "GG_OU_Dev", "GG_OU_Graphisme", "GG_OU_Audio", "GG_OU_Testing", "GG_OU_IT", "GG_OU_Administration", "GG_OU_Prodcom"

    Write-Host "PSOBarzini a été appliqué aux groupes spécifiés avec succès."

    # AGDLP
    # Ajout du groupe GG_OU_Dev aux groupes GDL_RO_OU_Graphisme et GDL_RO_OU_Audio
    $groupes = "GDL_RO_OU_Graphisme", "GDL_RO_OU_Audio"
    foreach ($groupe in $groupes) {
        if (Get-ADGroup -Identity $groupe) {
            Add-ADGroupMember -Identity $groupe -Members "GG_OU_Dev"
            Write-Host "Ajout du groupe GG_OU_Dev au groupe $groupe"
        }
        else {
            Write-Warning "Le groupe $groupe n'existe pas"
        }
    }
    # Ajout du groupe GG_OU_Directeur à tous les groupes GDL_RO
    $groupes = "GDL_RO_OU_Administration", "GDL_RO_OU_Prodcom", "GDL_RO_OU_Dev", "GDL_RO_OU_Graphisme", "GDL_RO_OU_Audio", "GDL_RO_OU_Testing", "GDL_RO_OU_IT"
    foreach ($groupe in $groupes) {
        if (Get-ADGroup -Identity $groupe) {
            Add-ADGroupMember -Identity $groupe -Members "GG_OU_Directeurs"
            Write-Host "Ajout du groupe GG_OU_Directeur au groupe $groupe"
        }
        else {
            Write-Warning "Le groupe $groupe n'existe pas"
        }
    }
}

catch {
    Write-Host "Une erreur s'est produite : $_"
}
