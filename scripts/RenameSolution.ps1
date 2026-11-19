<#
.SYNOPSIS
    Renames the JotunnModStub template solution to a custom mod name.
.DESCRIPTION
    One-time utility script used to scaffold a new mod from the JotunnModStub
    template. It renames folders, files, solution references, project references,
    and updates DoPrebuild.props and Environment.props accordingly.
#>

param(
	[string]$Selection = "",
	[string]$SolutionName = "",
	[string]$CopyEnvironmentProps = "",
	[switch]$NoCopy,
	[string]$cmdarg = ""
)

# Contributed by Kpro#3271
#uncomment to enable logging
#Start-Transcript -OutputDirectory "C:\transcripts\"

Write-Host ""
Write-Host ""
Write-Host "WELCOME TO JOTUNNMODSTUB RENAMING UTILITY"
Write-Host "-----------------------------------------"
Write-Host ""
Write-Host "This script will do the following:"
Write-Host ""
Write-Host ""
Write-Host "1. Change the file names, folder names, and project references from the JotunnModStub to your custom solution name."
Write-Host ""
Write-Host "2. Change the DoPrebuild.props file."
Write-Host ""
Write-Host "3. Create the Environment.props file."
Write-Host ""
Write-Host "4. Initialize a new Git repository in the copied solution folder."


$scriptsPath = $PSScriptRoot
$modstubpath = Split-Path $scriptsPath -Parent
$modstubfoldername = Split-Path -Path $modstubpath -leaf
$targetRoot = $modstubpath
$createNewCopy = $false
Write-Host ""

if ($NoCopy -or $cmdarg -eq "-nocopy") {
	$Name = $modstubfoldername
} else {
	#Check for rename and copy use-case
	Write-Host "Step 1. Choose one of the following options:"
	Write-Host ""
	Write-Host "1. Create a solution in this folder named '$modstubfoldername'"
	Write-Host ""
	Write-Host "2. Copy this folder to a new folder with a solution name I will choose"
	Write-Host ""
	$yn = $Selection
	if ([string]::IsNullOrWhiteSpace($yn)) {
		$yn = Read-Host "Select (1/2)?"
	}
	if ($yn -eq "1") 
	{
		$Name = $modstubfoldername
	}
	else
	{
		Write-Host ""
		Write-Host "Got it. A copy of this folder will be created with a new folder and solution name that you choose"
		$Name = $SolutionName
		if ([string]::IsNullOrWhiteSpace($Name)) {
			$Name = Read-Host "Enter a new name for the solution."
		}
		Write-Host ""

		#Copy modstub folder
		$destination = [System.IO.Path]::GetFullPath((Join-Path $modstubpath "..\..\MODS\$Name\$Name"))
		if (Test-Path -LiteralPath $destination) {
			throw "The destination folder already exists: $destination"
		}
		$modFolder = Split-Path $destination -Parent
		New-Item -ItemType Directory -Path $modFolder -Force | Out-Null
		New-Item -ItemType Directory -Path (Join-Path $modFolder "PUBLISH") -Force | Out-Null
		New-Item -ItemType Directory -Path $destination | Out-Null
		Get-ChildItem -LiteralPath $modstubpath -Force |
			Where-Object { $_.Name -notin @(".vs", ".idea", ".git") } |
			Copy-Item -Destination $destination -Recurse
		$targetRoot = $destination
		$createNewCopy = $true
		Write-Host "Working in solution folder: $destination"
	}
}

$solutionRoot = $targetRoot

#Rename folders and files

if ($Name -ne "")
{

Write-Host "     . . . Renaming files and folders to '$Name' . . ."
$projectRoot = Join-Path $solutionRoot "JotunnModStub"
if (Test-Path -LiteralPath $projectRoot) {
	Move-Item -LiteralPath $projectRoot -Destination (Join-Path $solutionRoot $Name)
}
$unity = $Name + "Unity"
$unityRoot = Join-Path $solutionRoot "JotunnModStubUnity"
if (Test-Path -LiteralPath $unityRoot) {
	if ($createNewCopy) {
		Remove-Item -LiteralPath $unityRoot -Recurse -Force
		Write-Host "Removed template Unity folder from the new solution copy."
	} else {
		Move-Item -LiteralPath $unityRoot -Destination (Join-Path $solutionRoot $unity)
	}
}
Get-ChildItem -LiteralPath $solutionRoot -File -Recurse | ForEach-Object {
	if ($_.Name -ne "JotunnModStub.zip" -and $_.Name.Contains("JotunnModStub")) {
		Rename-Item -LiteralPath $_.FullName -NewName $_.Name.Replace("JotunnModStub", $Name)
	}
}

# The template can use extension-only filenames to avoid baking the template name into filenames.
$solutionFile = Join-Path $solutionRoot "$Name.sln"
if (-not (Test-Path -LiteralPath $solutionFile) -and (Test-Path -LiteralPath (Join-Path $solutionRoot ".sln"))) {
	Rename-Item -LiteralPath (Join-Path $solutionRoot ".sln") -NewName "$Name.sln"
}
$projectDirectory = Join-Path $solutionRoot $Name
foreach ($extension in @(".cs", ".csproj")) {
	$unnamedFile = Join-Path $projectDirectory $extension
	if ((Test-Path -LiteralPath $unnamedFile) -and -not (Test-Path -LiteralPath (Join-Path $projectDirectory "$Name$extension"))) {
		Rename-Item -LiteralPath $unnamedFile -NewName "$Name$extension"
	}
}
}
else{
Write-Host "Error: empty solution name"
Read-Host "Enter to exit"
Exit 0
}

#Rename internal references
$msg = "     . . . Replacing internal references to 'JotunnModStub' with '$Name' . . ."
Write-Host $msg
$solutionFile = Join-Path $solutionRoot "$Name.sln"
$sourceFile = Join-Path $projectDirectory "$Name.cs"
$projectFile = Join-Path $projectDirectory "$Name.csproj"
((Get-Content -LiteralPath $solutionFile -Raw) -replace 'JotunnModStub',$Name) | Set-Content -LiteralPath $solutionFile
((Get-Content -LiteralPath $sourceFile -Raw) -replace 'JotunnModStub',$Name) | Set-Content -LiteralPath $sourceFile
$landed = $Name + " has landed"
((Get-Content -LiteralPath $sourceFile -Raw) -replace 'ModStub has landed',$landed) | Set-Content -LiteralPath $sourceFile
((Get-Content -LiteralPath $projectFile -Raw) -replace 'JotunnModStubUnity',$unity) -replace 'JotunnModStub',$Name | Set-Content -LiteralPath $projectFile
$assemblyInfo = Join-Path $projectDirectory "Properties\AssemblyInfo.cs"
if (Test-Path -LiteralPath $assemblyInfo) {
	((Get-Content -LiteralPath $assemblyInfo -Raw) -replace 'JotunnModStub',$Name) | Set-Content -LiteralPath $assemblyInfo
}



#setting DoPrebuild.props to true
Write-Host ""
Write-Host "Step 2. . . . setting DoPrebuid.props <ExecutePrebuild> to true..."
$prebuildProps = Join-Path $solutionRoot "DoPrebuild.props"
if (Test-Path -LiteralPath $prebuildProps) {
	((Get-Content -LiteralPath $prebuildProps -Raw) -replace 'False','True') | Set-Content -LiteralPath $prebuildProps
}

Write-Host ""


# Reuse Environment.props stored next to the template for every generated solution.
$sharedEnvironmentProps = Join-Path (Split-Path $modstubpath -Parent) "Environment.props"
if (Test-Path -LiteralPath $sharedEnvironmentProps) {	
	Write-Host ""
	$yn = $CopyEnvironmentProps
	if ([string]::IsNullOrWhiteSpace($yn)) {
		$yn = Read-Host "Step 3. . . . An Environment.Props file is dectected in the parent directory. Copy this file to solution directory (y/n)?"
	}
	 if ($yn -eq "y") {
		Copy-Item -LiteralPath $sharedEnvironmentProps -Destination $solutionRoot
	 } 	 else {
		Write-Host ""
		Write-Host "WARNING"
		Write-Host "-------"
		Write-Host ""	
		Write-Host "You must create an environment.props file inside the solution directory PRIOR to building the solution."
		Write-Host "Instructions for creating this file can be found at"
		Write-Host "https://github.com/Valheim-Modding/JotunnModStub"
		Write-Host ""
		Write-Host ""
		Read-Host "Hit Enter to Exit"
		Exit 1
	 }
} else {
		Write-Host ""
		Write-Host "Step 3 . . . . You must create an environment.props file inside the solution directory PRIOR to building the solution."
		Write-Host ""
$yn3 = $CopyEnvironmentProps
if ([string]::IsNullOrWhiteSpace($yn3)) {
	$yn3 = Read-Host " -- Would you like to create an environment.props file now (y/n)"
}
if ($yn3 -eq "y")
{
	#Initially assume typical install location
	$TypicalInstallFolder = "c:\Program Files (x86)\Steam\steamapps\common\Valheim"
	
	#Test for existence of typical install	
	if (Test-Path -Path $TypicalInstallFolder) {
		$ValheimFolder = $TypicalInstallFolder
	} else {
		$ValheimFolder = "$env:SystemDrive"
	}
	

	#Ask user to verify install folder
	
	function Get-InstallFolder($initialDirectory="") {   
		[void] [System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
		
		$OpenFolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
		$OpenFolderDialog.SelectedPath = $initialDirectory
		$OpenFolderDialog.Description = "Select Valheim Install Folder"
		$OpenFolderDialog.rootfolder = "MyComputer"
		[void] $OpenFolderDialog.ShowDialog()
		return $OpenFolderDialog.SelectedPath
	}
	
	Write-Host ""
	Write-Host " -- Hit ENTER to select your Valheim install folder"
	
	$verifiedinstallfolder = Get-InstallFolder($ValheimFolder)
	
	#Build environment.props
	$environmentProps = Join-Path $solutionRoot "environment.props"
	New-Item -ItemType File -Path $environmentProps
	Add-Content -Path $environmentProps -Value '<?xml version="1.0" encoding="utf-8"?>'
	Add-Content -Path $environmentProps -Value '<Project ToolsVersion="Current" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
	Add-Content -Path $environmentProps -Value '  <PropertyGroup>'
 	Add-Content -Path $environmentProps -Value '   <!-- Needs to be your path to the base Valheim folder -->'
	
	#Build Install Path
	$installpath = "    <VALHEIM_INSTALL>$verifiedinstallfolder</VALHEIM_INSTALL>"
	
	Add-Content -Path $environmentProps -Value $installpath
	Add-Content -Path $environmentProps -Value '    <!-- This is the folder where your build gets copied to when using the post-build automations -->'
	Add-Content -Path $environmentProps -Value '    <MOD_DEPLOYPATH>$(VALHEIM_INSTALL)\BepInEx\plugins</MOD_DEPLOYPATH>'
	Add-Content -Path $environmentProps -Value '  </PropertyGroup>'
	Add-Content -Path $environmentProps -Value '</Project>'
	
	#Copy environment.props next to the template for reuse by future generated solutions.
	Copy-Item -LiteralPath $environmentProps -Destination $sharedEnvironmentProps
	
	#check for existence of BepInEx folder
	if (Test-Path -Path $verifiedinstallfolder\BepInEx) {
		
	} else {
		Write-Host "WARNING: BepInEx is not installed."
	}
}

}

if ($createNewCopy) {
	$gitCommand = Get-Command git -ErrorAction SilentlyContinue
	if (-not $gitCommand) {
		throw "Git was not found in PATH; cannot initialize the new solution repository."
	}

	Write-Host "Initializing Git repository in '$solutionRoot'..."
	$gitDirectory = Join-Path $solutionRoot ".git"
	if (Test-Path -LiteralPath $gitDirectory) {
		Remove-Item -LiteralPath $gitDirectory -Recurse -Force
	}

	& $gitCommand.Source -C $solutionRoot init
	if ($LASTEXITCODE -ne 0) { throw "git init failed with exit code $LASTEXITCODE" }

	& $gitCommand.Source -C $solutionRoot add .
	if ($LASTEXITCODE -ne 0) { throw "git add failed with exit code $LASTEXITCODE" }

	& $gitCommand.Source -C $solutionRoot commit -m "chore: init"
	if ($LASTEXITCODE -ne 0) { throw "git commit failed with exit code $LASTEXITCODE" }
}

$copyFilesBat = Join-Path (Split-Path $modstubpath -Parent) "copy_files.bat"
if (-not (Test-Path -LiteralPath $copyFilesBat)) {
	throw "copy_files.bat was not found: $copyFilesBat"
}

$copyFilesDirectory = Split-Path $copyFilesBat -Parent
Write-Host "Running '$copyFilesBat'..."
Push-Location -LiteralPath $copyFilesDirectory
try {
	& $copyFilesBat
	if ($LASTEXITCODE -ne 0) {
		throw "copy_files.bat failed with exit code $LASTEXITCODE"
	}
}
finally {
	Pop-Location
}

Write-Host ""
Write-Host ""
Write-Host "Success"
Write-Host "-------"
Write-Host ""
Write-Host "The process is complete."
Write-Host "Note that, as stated in the wiki, the compiler will generate reference errors the first time you build the solution."
Write-Host "This is normal. Close VS2019/2022. Reopen the solution. Build. The errors should be resolved."
Write-Host ""
Write-Host ""
if ([string]::IsNullOrWhiteSpace($Selection)) {
	Read-Host "Hit Enter to Exit"
}

Write-Host ""
Write-Host ""
Exit 0
