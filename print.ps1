$ModelList = $null
$SelectedModel = $null
$global:SourceCSV = "\\*****\source.csv"
	Import-Csv $SourceCSV -delimiter ";" | Foreach { [array]$ModelList += $_.Name }

$ModelList
 [int]$temp = Read-Host "выбери модель. нумерация с 0 " 
 $global:SelectedModel = $ModelList["$temp"]

 Write-Host "$SelectedModel"

 $global:printerSource = Read-Host "ip адрес"


#######################################################################################

function Add-PrnDriver ($DeviceName, $Patch, $InfPath)
{
	cscript C:\Windows\System32\Printing_Admin_Scripts\ru-RU\prndrvr.vbs `
			-a -m $DeviceName -h $Patch -i $InfPath | Out-Null
}

function Add-scan
{
	
	param
	(
		$Driver,
		$VidPid,
		$IpAdress
		
	)
	new-psdrive -name P -psprovider FileSystem -root $FolderPrint
	
	
	Set-Location "P:"
	.\hpbniscan64.exe -f $Driver -m $VidPid -a $IpAdress
	
	Start-Sleep -Seconds 20
	
	Remove-PSDrive -Name 'P' -Force
	
}


Function CheckWeb
{
	
	param ([string][ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		$IpAdress,
		[string][ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		$Model,
		[switch]$Hp601_HP607,
		[switch]$Hp404_HP428)
	
	
	add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
	[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
	
	try
	{
		if ($Hp601_HP607.IsPresent)
		{
			$URL = "https://$IpAdress/"
			$Region = 'rawcontent'
			
		}
		Elseif ($Hp404_HP428.IsPresent)
		{
			$URL = "http://$IpAdress/DevMgmt/ProductConfigDyn.xml"
			$Region = 'content'
		}
		
		Else
		{
			$URL = "http://$IpAdress/"
			$Region = 'content'
			
		}
		
		$web = Invoke-WebRequest -Uri $URL -UseBasicParsing -ErrorAction SilentlyContinue
		$data = $web.$Region
		return $data.Contains("$Model")
		
	}
	
	catch
	{
		return $false
		
	}
			
}

function TestConnect
{
	
	param ([string][ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		$IpAdress,
		[string][ValidateNotNull()]
		[ValidateNotNullOrEmpty()]
		[Parameter(Mandatory = $true)]
		$Model)
	
	$tcpClient = New-Object System.Net.Sockets.TcpClient
	[bool]$testConnect = $tcpClient.ConnectAsync("$IpAdress", '80').Wait(1000)
	$tcpClient.Close()
	if ($testConnect)
	{
		if ($Model -like "*604*" -or $Model -like "*607*" -or $Model -like "*602*" -or $Model -like "*601*")
		{
			$Web = CheckWeb -IpAdress $IpAdress -Model $Model -Hp601_HP607
			
		}
		elseif ($Model -like "*404*" -or $Model -like "*428*")
		{
			$Web = CheckWeb -IpAdress $IpAdress -Model $Model -Hp404_HP428
			
		}
		else
		{
			
			$Web = CheckWeb -IpAdress $IpAdress -Model $Model
		}
	}
	Else
	{
		[bool]$Web = $false
	}
	
	return $testConnect, $Web
	
	
	
}

##########################################################################################
# ВСЕ ЧТО НИЖЕ ИСПОЛНЯЕМАЯ ЧАСТЬ

$DriverName = $null
	$FolderPrint = $null
	$DriverPathPrint = $null
	$DriverScan = $null
	$VidPidScan = $null
	$HostNameFull = $null
	$HostName = $null
	$printername = $null
	$printername2 = $null
	$driverpath = $null
	$WsdName = $null

	
	[array]$test = TestConnect -IpAdress $global:printerSource -Model $global:SelectedModel
	if ($test[0] -eq $true -and $test[1] -eq $true){
		$label_start.Visible = $true
		
		#Находим строку и доваляем переменные согласно ячейки
		$DriverName = (Select-String -Path $SourceCSV -Pattern $SelectedModel -List).Line.Split(";")[1]
		$FolderPrint = (Select-String -Path $SourceCSV -Pattern $SelectedModel -List).Line.Split(";")[2]
		$DriverPathPrint = (Select-String -Path $SourceCSV -Pattern $SelectedModel -List).Line.Split(";")[3]
		$DriverScan = (Select-String -Path $SourceCSV -Pattern $SelectedModel -List).Line.Split(";")[4]
		$VidPidScan = (Select-String -Path $SourceCSV -Pattern $SelectedModel -List).Line.Split(";")[5]
		
		if ($SelectedModel -like '*428*'){
			$WsdName = 'HP LaserJet Pro M428f-M429f'
			
		}
		
		elseif ($SelectedModel -like '*227sdn*'){
			$WsdName = 'HP LaserJet MFP M227sdn'
		}
		
		elseif ($SelectedModel -like '*227fdn*')
		{
			$WsdName = 'HP LaserJet MFP M227sdn'
		}
		
		
		
		$HostNameFull = [System.Net.Dns]::GetHostbyAddress("$printerSource")
		$HostName = $HostNameFull.HostName.Replace('.dellin.local', '')
		$printername2 = "$SelectedModel ($HostName)"
		$driverpath = "$FolderPrint\$DriverPathPrint"
		
		if ($SelectedModel -like '*428*' -or $SelectedModel -like '*M227*')
		{
			Add-PrnDriver $DriverName $FolderPrint $driverpath 
			
			Add-Printer -Name 'does_not_matter' -DeviceURL $global:printerSource
					
			Add-PrinterPort -Name $HostName -PrinterHostAddress $HostName
				
			Rename-Printer -Name "$HostName ($WsdName)" -NewName "SCANNER($SelectedModel)"
			Add-Printer -Name $printername2 -PortName $HostName -DriverName $DriverName
			Set-PrintConfiguration -PrinterName $printername2  -DuplexingMode OneSided
			
		}
		
		
		
		Else
		{
			Add-PrnDriver $DriverName $FolderPrint $driverpath #Пихаем драйвер в управление драйверами принтеров
		    Add-PrinterPort -Name $HostName -PrinterHostAddress $HostName
			Add-Printer -Name $printername2 -PortName $HostName -DriverName $DriverName
			
		}
		
		if ($VidPidScan -ne '' -and $VidPidScan -ne '$null')
		{
			Add-scan $DriverScan $VidPidScan $printerSource
			
			
			# Создаем ярлык для стандартного приложения сканирования. # Потом добавим добавление ярлыка на раб стол текущего юзера "$Home\Desktop\Сканирование". Или политикой добавить ярлык всем
			New-Item -ItemType SymbolicLink -Target 'C:\windows\system32\wiaacmgr.exe' -Path 'C:\Users\Public\Desktop\Сканирование' 
		}
		
		
		
	}
	Else
	{
		[System.Windows.Forms.MessageBox]::Show("IP адрес\модель указаны неверно или устройство выключено", 'Ошибка', 'OK', 'error')
	}
	
	
	